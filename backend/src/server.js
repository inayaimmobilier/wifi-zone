// =====================================================================
//  Wi-Fi Zone Village — serveur de vente automatique de tickets
//  Client -> page d'achat -> CinetPay (Mobile Money) -> notification -> ticket
//  MikroTik <- /api/router/sync (le routeur vient chercher ses tickets)
// =====================================================================
require('dotenv').config();
// Sur Render sans nom de domaine : on prend l'adresse publique fournie par Render
if (!process.env.PUBLIC_URL && process.env.RENDER_EXTERNAL_URL) process.env.PUBLIC_URL = process.env.RENDER_EXTERNAL_URL;
const path = require('path');
const crypto = require('crypto');
const express = require('express');
const rateLimit = require('express-rate-limit');
const { Pool } = require('pg');
const cinetpay = require('./cinetpay');

const { PORT = 3000, PUBLIC_URL, DATABASE_URL, STOCK_TARGET = 60 } = process.env;
for (const k of ['PUBLIC_URL', 'DATABASE_URL', 'CINETPAY_API_KEY', 'CINETPAY_API_PASSWORD']) {
  if (!process.env[k]) { console.error(`Variable manquante dans .env : ${k}`); process.exit(1); }
}

const db = new Pool({ connectionString: DATABASE_URL, ssl: /@(localhost|127.0.0.1)[:/]/.test(DATABASE_URL) ? false : { rejectUnauthorized: false }, max: 5 });
const app = express();
app.set('trust proxy', 1);

// ---------------------------------------------------------------- utilitaires
const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // sans 0/O, 1/I/L
function newCode(len = 6) {
  const b = crypto.randomBytes(len);
  return Array.from(b, (x) => ALPHABET[x % ALPHABET.length]).join('');
}
function normalizePhone(raw, dial) {
  let d = String(raw || '').replace(/\D/g, '');
  if (d.startsWith('00')) d = d.slice(2);
  if (!d.startsWith(dial)) d = dial + d;          // garde le 0 initial (CI/BJ : 10 chiffres)
  return d.length >= 11 && d.length <= 15 ? d : null;
}
const safeEq = (a, b) => {
  const x = Buffer.from(String(a)), y = Buffer.from(String(b));
  return x.length === y.length && crypto.timingSafeEqual(x, y);
};
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// --------------------------------------------- finaliser un paiement (idempotent)
// Appelée par la notification CinetPay ET par la page ticket (filet de sécurité).
// On ne croit JAMAIS la notification seule : on redemande le statut à CinetPay.
// Le montant est fixé par NOTRE serveur à la création : il ne vient jamais du navigateur.
async function finalize(paymentId) {
  const { rows: [p] } = await db.query('select * from payments where id=$1', [paymentId]);
  if (!p || p.status !== 'pending' || !p.ref) return;
  const st = await cinetpay.getStatus(p.ref);
  if (st.state === 'success') {
    await db.query('select assign_ticket($1,$2)', [paymentId, st.method]);
  } else if (st.state === 'failed') {
    await db.query("update payments set status='failed', completed_at=now() where id=$1 and status='pending'", [paymentId]);
  }
}

// ======================================================= NOTIFICATION CINETPAY
// CinetPay envoie {notify_token, transaction_id, merchant_transaction_id}.
// On vérifie que notify_token est bien celui reçu à la création du paiement.
app.post('/api/cinetpay/notify', express.json({ limit: '50kb' }), express.urlencoded({ extended: false, limit: '50kb' }),
  async (req, res) => {
    const b = req.body || {};
    const ref = String(b.merchant_transaction_id || '');
    try {
      const { rows: [p] } = await db.query('select id, notify_token from payments where ref=$1', [ref]);
      if (!p || !p.notify_token || !safeEq(b.notify_token || '', p.notify_token)) {
        return res.status(401).json({ error: 'notification invalide' });
      }
      await db.query('update payments set provider_id=coalesce(provider_id,$2) where id=$1', [p.id, b.transaction_id || null]);
      await finalize(p.id);
      res.status(200).json({ ok: true });
    } catch (e) {
      console.error('notify', e.message);
      res.status(500).json({ error: 'réessayez' });      // CinetPay renverra la notification
    }
  });
app.get('/api/cinetpay/notify', (_, res) => res.status(200).send('ok')); // test d'accessibilité

app.use(express.json({ limit: '20kb' }));
app.use(express.static(path.join(__dirname, '..', 'public')));
app.get('/api/health', (_, res) => res.json({ status: 'ok', paiement: cinetpay.isSandbox() ? 'bac a sable' : 'production' }));

// ============================================================ API PUBLIQUE CLIENT
const payLimiter = rateLimit({ windowMs: 60_000, max: 10 });

// Forfaits d'une zone (avec disponibilité)
app.get('/api/zones/:id', async (req, res) => {
  try {
    const { rows: [z] } = await db.query(
      'select id,name,country,dial_code,support_phone from zones where id=$1', [req.params.id]);
    if (!z) return res.status(404).json({ error: 'Zone inconnue' });
    const { rows: offers } = await db.query(`
      select p.id,p.label,p.price,
        (select count(*) from tickets t where t.pricing_id=p.id and t.status='free' and t.channel='online')::int as stock
      from pricings p where p.zone_id=$1 and p.active order by p.sort, p.price`, [z.id]);
    res.json({ zone: z, offers: offers.map((o) => ({ ...o, available: o.stock > 0, stock: undefined })) });
  } catch (e) { res.status(400).json({ error: 'Zone invalide' }); }
});

// Démarrer un paiement
app.post('/api/pay', payLimiter, async (req, res) => {
  try {
    const { zoneId, pricingId, phone, login } = req.body || {};
    const { rows: [z] } = await db.query('select * from zones where id=$1', [zoneId]);
    if (!z) return res.status(404).json({ error: 'Zone inconnue' });
    const { rows: [p] } = await db.query(
      'select * from pricings where id=$1 and zone_id=$2 and active', [pricingId, z.id]);
    if (!p) return res.status(404).json({ error: 'Forfait inconnu' });
    const tel = normalizePhone(phone, z.dial_code);
    if (!tel) return res.status(400).json({ error: 'Numéro de téléphone invalide' });

    // Ne JAMAIS faire payer s'il n'y a plus de ticket
    const { rows: [s] } = await db.query(
      "select count(*)::int n from tickets where pricing_id=$1 and status='free' and channel='online'", [p.id]);
    if (s.n < 1) return res.status(409).json({ error: 'Forfait momentanément épuisé, réessayez dans 2 minutes' });

    // Adresse de connexion du hotspot transmise par login.html (http://login.wifi/login)
    const loginUrl = /^http:\/\/[a-z0-9.-]+(:\d+)?\/login$/i.test(login || '') ? login : null;
    // Référence courte et imprévisible (CinetPay : 30 caractères max) — sert aussi de clé à la page ticket
    const ref = 'WZ' + crypto.randomBytes(12).toString('hex').toUpperCase();
    const { rows: [pay] } = await db.query(
      `insert into payments(zone_id,pricing_id,pricing_label,amount,phone,ref,login_url)
       values($1,$2,$3,$4,$5,$6,$7) returning id`, [z.id, p.id, p.label, p.price, tel, ref, loginUrl]);

    const back = `${PUBLIC_URL}/ticket.html?r=${ref}`;
    const cp = await cinetpay.initPayment({
      ref, amount: p.price,
      designation: `Ticket Wi-Fi ${p.label} - ${z.name}`.slice(0, 255),
      phone: tel,
      email: `client${tel}@${new URL(PUBLIC_URL).hostname}`,
      successUrl: back, failedUrl: back,
      notifyUrl: `${PUBLIC_URL}/api/cinetpay/notify`,
    });
    await db.query('update payments set notify_token=$2, provider_id=$3 where id=$1',
      [pay.id, cp.notifyToken, cp.transactionId]);
    // Avec le canal PUSH, CinetPay peut envoyer la demande directement sur le téléphone :
    // dans ce cas pas de page de paiement, on va directement attendre le ticket.
    res.json({ checkout_url: cp.paymentUrl || back, payment_id: ref });
  } catch (e) {
    console.error('pay', e.message);
    res.status(502).json({ error: 'Paiement indisponible, réessayez' });
  }
});

// Statut du paiement + ticket (la page ticket.html l'interroge toutes les 3 s)
// Accepte la référence WZ... (ou l'identifiant interne)
app.get('/api/payment/:key', async (req, res) => {
  try {
    const key = req.params.key;
    const where = UUID.test(key) ? 'id=$1' : 'ref=$1';
    let { rows: [p] } = await db.query(`select * from payments where ${where}`, [key]);
    if (!p) return res.status(404).json({ error: 'Paiement inconnu' });
    if (p.status === 'pending' && Date.now() - new Date(p.created_at) > 8000) {
      await finalize(p.id).catch((e) => console.error('finalize', e.message));
      ({ rows: [p] } = await db.query('select * from payments where id=$1', [p.id]));
    }
    let code = null;
    if (p.ticket_id) ({ rows: [{ code }] } = await db.query('select code from tickets where id=$1', [p.ticket_id]));
    res.json({ status: p.status, label: p.pricing_label, amount: p.amount, code, login: p.login_url });
  } catch { res.status(400).json({ error: 'Paiement invalide' }); }
});

// Retrouver ses tickets (numéro de téléphone + montant payé, pour limiter les abus)
app.post('/api/recover', rateLimit({ windowMs: 60_000, max: 5 }), async (req, res) => {
  const { zoneId, phone, amount } = req.body || {};
  try {
    const { rows: [z] } = await db.query('select dial_code from zones where id=$1', [zoneId]);
    const tel = z && normalizePhone(phone, z.dial_code);
    if (!tel) return res.status(400).json({ error: 'Numéro invalide' });
    const { rows } = await db.query(`
      select t.code, p.pricing_label as label, p.completed_at as date
        from payments p join tickets t on t.id=p.ticket_id
       where p.zone_id=$1 and p.phone=$2 and p.amount=$3 and p.status='success'
         and p.completed_at > now() - interval '35 days'
       order by p.completed_at desc limit 5`, [zoneId, tel, Number(amount)]);
    res.json({ tickets: rows });
  } catch { res.status(400).json({ error: 'Requête invalide' }); }
});

// ============================================================ API ROUTEUR MIKROTIK
async function checkRouter(req, res) {
  const { zone, token } = req.query;
  const { rows: [z] } = await db.query('select * from zones where id=$1', [zone]).catch(() => ({ rows: [] }));
  if (!z || !safeEq(token || '', z.router_token)) { res.status(403).send('# acces refuse\n'); return null; }
  return z;
}

// Le routeur récupère ici un script .rsc qui crée les nouveaux tickets.
app.get('/api/router/sync', async (req, res) => {
  const z = await checkRouter(req, res); if (!z) return;
  const client = await db.connect();
  try {
    await client.query('begin');
    await client.query('update zones set last_sync_at=now() where id=$1', [z.id]);
    // 1. Réapprovisionner le stock de chaque forfait
    const { rows: pricings } = await client.query('select * from pricings where zone_id=$1 and active', [z.id]);
    for (const p of pricings) {
      const { rows: [c] } = await client.query(
        "select count(*)::int n from tickets where pricing_id=$1 and status<>'sold' and channel='online'", [p.id]);
      const missing = Number(STOCK_TARGET) - c.n;
      for (let i = 0; i < missing; i++) {
        await client.query(
          'insert into tickets(zone_id,pricing_id,code) values($1,$2,$3) on conflict do nothing',
          [z.id, p.id, newCode(p.uptime.endsWith('h') ? 5 : 6)]);
      }
    }
    // 2. Envoyer les tickets pas encore confirmés (ou tous les libres si ?full=1 après un reset)
    const statuses = req.query.full === '1' ? ['pending_router', 'pushing', 'free'] : ['pending_router', 'pushing'];
    const batch = crypto.randomUUID();
    const { rows: list } = await client.query(`
      update tickets t set status = case when t.status='free' then 'free' else 'pushing' end, batch_id=$3
        from pricings p
       where t.pricing_id=p.id and t.zone_id=$1 and t.status = any($2)
         and t.id in (select id from tickets where zone_id=$1 and status = any($2) order by id limit 300)
      returning t.code, p.profile, p.uptime, p.id as pid`, [z.id, statuses, batch]);
    await client.query('commit');

    const lines = ['# sync ' + new Date().toISOString()];
    for (const t of list) {
      lines.push(`:if ([:len [/ip hotspot user find name="${t.code}"]]=0) do={/ip hotspot user add server=all ` +
        `name="${t.code}" password="${t.code}" profile="${t.profile}" limit-uptime=${t.uptime} comment="auto:${t.pid}"}`);
    }
    if (list.length) {
      const ack = `${PUBLIC_URL}/api/router/ack?zone=${z.id}&token=${z.router_token}&batch=${batch}`;
      lines.push(`/tool fetch url="${ack}" mode=https check-certificate=yes output=none`);
      lines.push(`:log info "sync-tickets : ${list.length} tickets ajoutes"`);
    }
    res.type('text/plain').send(lines.join('\n') + '\n');
  } catch (e) {
    await client.query('rollback').catch(() => {});
    console.error('sync', e.message);
    res.status(500).send('# erreur\n');
  } finally { client.release(); }
});

// Le routeur confirme : les tickets du lot deviennent vendables.
app.get('/api/router/ack', async (req, res) => {
  const z = await checkRouter(req, res); if (!z) return;
  const { rowCount } = await db.query(
    "update tickets set status='free' where zone_id=$1 and batch_id=$2 and status='pushing'",
    [z.id, req.query.batch]).catch(() => ({ rowCount: 0 }));
  res.type('text/plain').send(`# ${rowCount} ok\n`);
});

// ============================================================ TABLEAU DE BORD GÉRANT
// Page : https://mazone.com/admin.html  —  mot de passe = ADMIN_PASSWORD (fichier .env / Render)
const FEE = Number(process.env.COMMISSION_PERCENT || 3) / 100;  // commission CinetPay de ton contrat
const adminLimiter = rateLimit({ windowMs: 15 * 60_000, max: 300 });
function admin(req, res, next) {
  const pw = process.env.ADMIN_PASSWORD;
  const given = (req.get('Authorization') || '').replace(/^Bearer /, '');
  if (!pw || pw.length < 10) return res.status(503).json({ error: 'ADMIN_PASSWORD absent ou trop court (10 caractères min.)' });
  if (!safeEq(given, pw)) return res.status(401).json({ error: 'Mot de passe incorrect' });
  next();
}
app.use('/api/admin', adminLimiter, admin);

app.get('/api/admin/zones', async (_, res) => {
  const { rows } = await db.query('select id, name, country, last_sync_at from zones order by created_at');
  res.json(rows);
});

app.get('/api/admin/stats', async (req, res) => {
  try {
    const zone = req.query.zone;
    const days = Math.min(Math.max(parseInt(req.query.days, 10) || 30, 1), 365);
    const ok = "zone_id=$1 and status='success'";
    const fee = (col) => `round(${col} * ${FEE})`;   // arrondi au franc, ligne par ligne
    const q = (sql, params = [zone]) => db.query(sql, params).then((r) => r.rows);
    const [[z], [kpi], daily, byPricing, byMethod, stock, recent, issues, [pend]] = await Promise.all([
      q('select id, name, last_sync_at from zones where id=$1'),
      q(`select
           coalesce(sum(amount) filter (where completed_at::date = now()::date),0)::int as today_gross,
           count(*) filter (where completed_at::date = now()::date)::int as today_tickets,
           coalesce(sum(amount) filter (where completed_at > now()-interval '7 days'),0)::int as week_gross,
           coalesce(sum(amount) filter (where completed_at > now()-interval '30 days'),0)::int as month_gross,
           count(*) filter (where completed_at > now()-interval '30 days')::int as month_tickets,
           coalesce(sum(amount - ${fee('amount')}) filter (where completed_at > now()-interval '30 days'),0)::int as month_net,
           coalesce(sum(amount),0)::int as all_gross
         from payments where ${ok}`),
      q(`select to_char(d,'YYYY-MM-DD') as day, coalesce(sum(p.amount),0)::int as gross,
                coalesce(sum(p.amount - ${fee('p.amount')}),0)::int as net, count(p.id)::int as tickets
           from generate_series(now()::date - ($2::int - 1), now()::date, interval '1 day') d
           left join payments p on p.zone_id=$1 and p.status='success' and p.completed_at::date = d::date
          group by d order by d`, [zone, days]),
      q(`select pricing_label as label, count(*)::int as tickets, sum(amount)::int as gross
           from payments where ${ok} and completed_at > now() - ($2::int * interval '1 day')
          group by 1 order by 3 desc`, [zone, days]),
      q(`select coalesce(method,'inconnu') as method, count(*)::int as tickets, sum(amount)::int as gross
           from payments where ${ok} and completed_at > now() - ($2::int * interval '1 day')
          group by 1 order by 3 desc`, [zone, days]),
      q(`select p.id, p.label, p.price, p.profile, p.active,
                count(t.id) filter (where t.status='free' and t.channel='online')::int as free,
                count(t.id) filter (where t.status in ('pending_router','pushing') and t.channel='online')::int as waiting,
                count(t.id) filter (where t.status='sold')::int as sold,
                count(t.id) filter (where t.channel='paper')::int as paper
           from pricings p left join tickets t on t.pricing_id=p.id
          where p.zone_id=$1 group by p.id order by p.sort, p.price`),
      q(`select p.id, p.created_at, p.completed_at, p.phone, p.amount, p.pricing_label as label,
                p.method, p.status, t.code
           from payments p left join tickets t on t.id=p.ticket_id
          where p.zone_id=$1 order by p.created_at desc limit 40`),
      q(`select id, created_at, phone, amount, pricing_label as label from payments
          where zone_id=$1 and status='paid_no_stock' order by created_at`),
      q(`select count(*)::int as n from payments
          where zone_id=$1 and status='pending' and created_at between now()-interval '1 day' and now()-interval '10 minutes'`),
    ]);
    if (!z) return res.status(404).json({ error: 'Zone inconnue' });
    res.json({ zone: z, fee_percent: FEE * 100, kpi, daily, byPricing, byMethod, stock, recent, issues,
               stale_pending: pend.n, stock_target: Number(STOCK_TARGET) });
  } catch (e) { console.error('admin/stats', e.message); res.status(400).json({ error: 'Requête invalide' }); }
});

// Re-tenter l'attribution d'un ticket à un client payé sans stock (quand le stock est revenu)
app.post('/api/admin/resolve/:id', async (req, res) => {
  try {
    const { rows: [r] } = await db.query('select assign_ticket($1, null) as code', [req.params.id]);
    if (!r.code) return res.status(409).json({ error: 'Toujours aucun ticket libre pour ce forfait' });
    res.json({ code: r.code });
  } catch { res.status(400).json({ error: 'Paiement invalide' }); }
});

// Vérifier chez CinetPay un paiement resté "pending"
app.post('/api/admin/recheck/:id', async (req, res) => {
  try { await finalize(req.params.id); res.json({ ok: true }); }
  catch (e) { res.status(502).json({ error: e.message }); }
});

// Modifier un forfait : prix ou activation (le nom du profil MikroTik ne change pas)
app.patch('/api/admin/pricing/:id', async (req, res) => {
  const { price, active } = req.body || {};
  if (price !== undefined && !(Number.isInteger(price) && price >= 100))
    return res.status(400).json({ error: 'Prix entier, minimum 100 F' });
  const { rowCount } = await db.query(
    'update pricings set price=coalesce($2,price), active=coalesce($3,active) where id=$1',
    [req.params.id, price ?? null, typeof active === 'boolean' ? active : null]).catch(() => ({ rowCount: 0 }));
  rowCount ? res.json({ ok: true }) : res.status(404).json({ error: 'Forfait inconnu' });
});

// ---------------------------------------------------------------- TICKETS PAPIER
// Les tickets papier sont créés par le serveur, envoyés au routeur par la même synchro,
// mais ne sont JAMAIS vendus en ligne (channel='paper'). Tu les imprimes et tu les
// confies aux revendeurs (boutiques, kiosques) qui les vendent en espèces.
app.post('/api/admin/paper', async (req, res) => {
  const { zoneId, pricingId } = req.body || {};
  const qty = parseInt(req.body?.qty, 10);
  if (!(qty >= 1 && qty <= 400)) return res.status(400).json({ error: 'Quantité entre 1 et 400' });
  try {
    const { rows: [p] } = await db.query('select * from pricings where id=$1 and zone_id=$2', [pricingId, zoneId]);
    if (!p) return res.status(404).json({ error: 'Forfait inconnu' });
    const d = new Date();
    const lot = `${p.profile}-${d.toISOString().slice(2, 10).replace(/-/g, '')}-${crypto.randomBytes(2).toString('hex').toUpperCase()}`;
    let made = 0;
    for (let tries = 0; made < qty && tries < qty * 3; tries++) {
      const r = await db.query(
        `insert into tickets(zone_id,pricing_id,code,channel,lot) values($1,$2,$3,'paper',$4) on conflict do nothing`,
        [zoneId, p.id, newCode(6), lot]);
      made += r.rowCount;
    }
    res.json({ lot, qty: made });
  } catch (e) { console.error('paper', e.message); res.status(400).json({ error: 'Requête invalide' }); }
});

app.get('/api/admin/paper', async (req, res) => {
  const { rows } = await db.query(`
    select t.lot, p.label, p.price, min(t.created_at) as created_at, count(*)::int as qty,
           count(*) filter (where t.status in ('free','sold'))::int as on_router
      from tickets t join pricings p on p.id=t.pricing_id
     where t.zone_id=$1 and t.channel='paper'
     group by t.lot, p.label, p.price order by min(t.created_at) desc limit 50`, [req.query.zone])
    .catch(() => ({ rows: [] }));
  res.json(rows);
});

app.get('/api/admin/paper/:lot', async (req, res) => {
  const { rows } = await db.query(`
    select t.code, t.status, p.label, p.price, z.name as zone, z.support_phone
      from tickets t join pricings p on p.id=t.pricing_id join zones z on z.id=t.zone_id
     where t.lot=$1 and t.channel='paper' order by t.id`, [req.params.lot]);
  if (!rows.length) return res.status(404).json({ error: 'Lot inconnu' });
  res.json({ lot: req.params.lot, zone: rows[0].zone, support: rows[0].support_phone,
    label: rows[0].label, price: rows[0].price,
    on_router: rows.filter((r) => r.status === 'free' || r.status === 'sold').length,
    codes: rows.map((r) => r.code) });
});

// Export comptable CSV (s'ouvre dans Excel)
app.get('/api/admin/export.csv', async (req, res) => {
  const days = Math.min(Math.max(parseInt(req.query.days, 10) || 30, 1), 365);
  const { rows } = await db.query(`
    select to_char(completed_at,'YYYY-MM-DD HH24:MI') as date, pricing_label, amount, method, phone,
           round(amount * ${FEE})::int as commission, (amount - round(amount * ${FEE}))::int as net
      from payments where zone_id=$1 and status='success' and completed_at > now() - ($2::int * interval '1 day')
     order by completed_at`, [req.query.zone, days]).catch(() => ({ rows: [] }));
  const esc = (v) => `"${String(v ?? '').replace(/"/g, '""')}"`;
  const lines = ['date;forfait;montant;operateur;telephone;commission;net',
    ...rows.map((r) => [r.date, r.pricing_label, r.amount, r.method, r.phone, r.commission, r.net].map(esc).join(';'))];
  res.type('text/csv; charset=utf-8')
     .set('Content-Disposition', `attachment; filename="ventes-${days}j.csv"`)
     .send('﻿' + lines.join('\r\n'));
});

app.listen(PORT, () => console.log(`Wi-Fi Zone en ligne sur le port ${PORT}`));
