// Crée ta zone + les 4 forfaits, puis affiche ZONE_ID et ROUTER_TOKEN
//   npm run zone:create -- "VILLAGE WI-FI" CI 2250700000000
require('dotenv').config();
// Adresse publique : PUBLIC_URL, sinon celle fournie par Render ou Railway
if (!process.env.PUBLIC_URL) {
  const auto = process.env.RENDER_EXTERNAL_URL || (process.env.RAILWAY_PUBLIC_DOMAIN ? `https://${process.env.RAILWAY_PUBLIC_DOMAIN}` : "");
  if (auto) process.env.PUBLIC_URL = auto;
}
const { Pool } = require('pg');
const db = new Pool({ connectionString: process.env.DATABASE_URL, ssl: /@(localhost|127.0.0.1)[:/]/.test(process.env.DATABASE_URL) ? false : { rejectUnauthorized: false } });

const COUNTRIES = {
  CI: { dial: '225', methods: ['OM_CI', 'MTN_CI', 'MOOV_CI', 'WAVE_CI'] },
  BJ: { dial: '229', methods: ['MTN_BJ', 'MOOV_BJ'] },
  TG: { dial: '228', methods: ['MOOV_TG', 'TMONEY_TG'] },
  SN: { dial: '221', methods: ['OM_SN', 'WAVE_SN', 'FREE_SN'] },
  ML: { dial: '223', methods: ['OM_ML', 'MOOV_ML'] },
  BF: { dial: '226', methods: ['OM_BF', 'MOOV_BF', 'WAVE_BF'] },
};
// profile = nom EXACT du profil MikroTik ; uptime = temps de connexion du ticket
const FORFAITS = [
  { profile: '1H',  label: '1 heure',   price: 100,  uptime: '1h',  sort: 1 },
  { profile: '24H', label: '24 heures', price: 200,  uptime: '1d',  sort: 2 },
  { profile: '7J',  label: '7 jours',   price: 1000, uptime: '7d',  sort: 3 },
  { profile: '30J', label: '30 jours',  price: 3000, uptime: '30d', sort: 4 },
];

(async () => {
  const [name = 'VILLAGE WI-FI', country = 'CI', support = null] = process.argv.slice(2);
  const c = COUNTRIES[country];
  if (!c) throw new Error('Pays inconnu : ' + Object.keys(COUNTRIES).join(', '));
  const { rows: [z] } = await db.query(
    'insert into zones(name,country,dial_code,methods,support_phone) values($1,$2,$3,$4,$5) returning *',
    [name, country, c.dial, c.methods, support]);
  for (const f of FORFAITS) {
    await db.query('insert into pricings(zone_id,profile,label,price,uptime,sort) values($1,$2,$3,$4,$5,$6)',
      [z.id, f.profile, f.label, f.price, f.uptime, f.sort]);
  }
  const url = process.env.PUBLIC_URL;
  console.log('\nZone créée :', z.name);
  console.log('ZONE_ID      =', z.id);
  console.log('ROUTER_TOKEN =', z.router_token, '  (secret ! à ne mettre que dans le routeur)');
  console.log('\nURL de synchro à mettre dans 02-sync-tickets.rsc :');
  console.log(`${url}/api/router/sync?zone=${z.id}&token=${z.router_token}`);
  console.log('\nLien d\'achat pour login.html :', `${url}/acheter.html?zone=${z.id}`);
  console.log('Tableau de bord :', `${url}/admin.html  (mot de passe = ADMIN_PASSWORD du .env)`);
  await db.end();
})().catch((e) => { console.error(e.message); process.exit(1); });
