// =====================================================================
//  Client CinetPay (API v1, 2026) — écrit d'après le SDK officiel
//  github.com/cinetpay/cinetpay-go  (auth.go, payment.go, webhook.go)
//
//  1. POST /v1/oauth/login   {api_key, api_password}      -> access_token (valable ~24 h)
//  2. POST /v1/payment       (Bearer token)               -> payment_url, notify_token
//  3. GET  /v1/payment/{merchant_transaction_id}           -> status (SUCCESS, FAILED, ...)
//  4. Notification POST JSON sur notify_url : {notify_token, transaction_id, merchant_transaction_id}
//
//  Clé sk_test_... -> bac à sable https://api.cinetpay.net
//  Clé sk_live_... -> production    https://api.cinetpay.co
// =====================================================================
const KEY = process.env.CINETPAY_API_KEY || '';
const PASSWORD = process.env.CINETPAY_API_PASSWORD || '';
const BASE = process.env.CINETPAY_BASE_URL ||
  (KEY.startsWith('sk_live_') ? 'https://api.cinetpay.co' : 'https://api.cinetpay.net');

const PAID = new Set(['SUCCESS']);
const FAILED = new Set(['FAILED', 'EXPIRED', 'INSUFFICIENT_BALANCE', 'USER_NOT_FOUND',
  'USER_IS_BLOCKED', 'NOT_ALLOWED', 'OTP_ERROR', 'OTP_EXPIRED']);
const OK_CODES = new Set([200, 100, 2001, 2002]);   // codes "pas une erreur" selon le SDK

let token = null, tokenExp = 0, pending = null;

async function call(method, path, body, bearer, tolerant = false) {
  const r = await fetch(BASE + path, {
    method,
    headers: { Accept: 'application/json', 'Content-Type': 'application/json',
               ...(bearer ? { Authorization: 'Bearer ' + bearer } : {}) },
    body: body ? JSON.stringify(body) : undefined,
    signal: AbortSignal.timeout(30000),
  });
  const data = await r.json().catch(() => ({}));
  const code = Number(data.code);
  // tolerant : une transaction ÉCHOUÉE peut revenir avec un code d'erreur, on veut quand même lire son statut
  if (tolerant && r.status < 500 && data.status && ![1002, 1003, 1004, 1005].includes(code)) return data;
  if (r.status >= 400 || (!Number.isNaN(code) && data.code !== undefined && !OK_CODES.has(code))) {
    const err = new Error(`CinetPay ${r.status}/${data.code ?? '-'} ${data.status || ''} ${data.description || data.message || ''}`.trim());
    err.apiCode = code;
    throw err;
  }
  return data;
}

async function getToken(force = false) {
  if (!force && token && Date.now() < tokenExp) return token;
  if (pending) return pending;                       // une seule connexion à la fois
  pending = call('POST', '/v1/oauth/login', { api_key: KEY, api_password: PASSWORD })
    .then((d) => {
      if (!d.access_token) throw new Error('CinetPay : connexion refusée (vérifie la clé et le mot de passe API)');
      token = d.access_token; tokenExp = Date.now() + 23 * 3600_000;
      return token;
    })
    .finally(() => { pending = null; });
  return pending;
}

async function authed(method, path, body, tolerant) {
  try { return await call(method, path, body, await getToken(), tolerant); }
  catch (e) {
    if (e.apiCode === 1003 || e.apiCode === 1002) return call(method, path, body, await getToken(true), tolerant);
    throw e;
  }
}

/** Crée le paiement. Retourne { paymentUrl, notifyToken, transactionId, status }. */
async function initPayment({ ref, amount, designation, phone, email, successUrl, failedUrl, notifyUrl }) {
  const d = await authed('POST', '/v1/payment', {
    currency: 'XOF',
    merchant_transaction_id: ref,          // 30 caractères maximum
    amount,                                // entier, 100 F minimum
    lang: 'fr',
    designation,
    client_email: email,
    client_first_name: 'Client',
    client_last_name: 'WiFi',
    client_phone_number: '+' + phone,      // format international +225...
    success_url: successUrl,               // 120 caractères maximum
    failed_url: failedUrl,
    notify_url: notifyUrl,
    channel: 'PUSH',
  });
  return { paymentUrl: d.payment_url || null, notifyToken: d.notify_token || null,
           transactionId: d.transaction_id || null, status: d.details?.status || d.status };
}

/** Statut d'un paiement : 'success' | 'failed' | 'pending' (+ statut brut). */
async function getStatus(ref) {
  const d = await authed('GET', '/v1/payment/' + encodeURIComponent(ref), undefined, true);
  const raw = String(d.status || '').toUpperCase();
  return {
    state: PAID.has(raw) ? 'success' : FAILED.has(raw) ? 'failed' : 'pending',
    raw,
    method: d.payment_method || d.details?.payment_method || null,
  };
}

const configured = () => Boolean(KEY && PASSWORD);
const isSandbox = () => !KEY.startsWith('sk_live_');
module.exports = { initPayment, getStatus, configured, isSandbox, BASE };
