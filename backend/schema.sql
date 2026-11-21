-- =====================================================================
--  Base de données Wi-Fi Zone  (à coller dans Supabase > SQL Editor > Run)
-- =====================================================================
create extension if not exists pgcrypto;

create table if not exists zones (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  country       text not null default 'CI',          -- CI, BJ, TG, SN, ML, BF
  dial_code     text not null default '225',
  methods       text[] not null default array['OM_CI','MTN_CI','MOOV_CI','WAVE_CI'],
  support_phone text,
  router_token  text not null default encode(gen_random_bytes(24),'hex'),
  last_sync_at  timestamptz,
  created_at    timestamptz not null default now()
);

create table if not exists pricings (
  id         serial primary key,
  zone_id    uuid not null references zones(id) on delete cascade,
  profile    text not null,          -- nom EXACT du profil MikroTik (1H, 24H, 7J, 30J)
  label      text not null,          -- affiché au client : "24 heures"
  price      integer not null check (price >= 100),   -- F CFA (CinetPay refuse < 100)
  uptime     text not null,          -- limit-uptime RouterOS : 1h, 1d, 7d, 30d
  sort       integer not null default 0,
  active     boolean not null default true
);

-- Statuts d'un ticket :
--   pending_router : créé par le serveur, pas encore sur le routeur
--   pushing        : envoyé au routeur, en attente de confirmation
--   free           : confirmé sur le routeur => VENDABLE
--   sold           : vendu
create table if not exists tickets (
  id          bigserial primary key,
  zone_id     uuid not null references zones(id) on delete cascade,
  pricing_id  integer not null references pricings(id),
  code        text not null,
  status      text not null default 'pending_router'
              check (status in ('pending_router','pushing','free','sold')),
  batch_id    uuid,
  payment_id  uuid,
  sold_at     timestamptz,
  channel     text not null default 'online' check (channel in ('online','paper')),
  lot         text,                -- lot de tickets papier (revendeurs)
  created_at  timestamptz not null default now(),
  unique (zone_id, code)
);
-- Mise à jour d'une base déjà créée (sans effet si les colonnes existent déjà)
alter table tickets add column if not exists channel text not null default 'online';
alter table tickets add column if not exists lot text;
create index if not exists tickets_lot_idx on tickets (zone_id, lot);
create index if not exists tickets_stock_idx on tickets (zone_id, pricing_id, status);

create table if not exists payments (
  id             uuid primary key default gen_random_uuid(),
  zone_id        uuid not null references zones(id),
  pricing_id     integer not null references pricings(id),
  pricing_label  text not null,      -- instantané : l'historique survit à la suppression d'un tarif
  amount         integer not null,
  phone          text not null,
  ref            text unique,       -- référence envoyée à CinetPay (merchant_transaction_id, 30 car. max)
  provider_id    text,              -- identifiant de transaction CinetPay
  notify_token   text,              -- jeton qui authentifie les notifications CinetPay
  login_url      text,              -- adresse du hotspot pour la connexion en 1 clic
  method         text,
  status         text not null default 'pending'
                 check (status in ('pending','success','failed','cancelled','paid_no_stock')),
  ticket_id      bigint references tickets(id),
  created_at     timestamptz not null default now(),
  completed_at   timestamptz
);
create index if not exists payments_phone_idx on payments (phone, created_at desc);
-- Mise à jour d'une base déjà créée
alter table payments add column if not exists ref text unique;
alter table payments add column if not exists provider_id text;
alter table payments add column if not exists notify_token text;
alter table payments add column if not exists login_url text;

-- Attribution ATOMIQUE : un paiement => un seul ticket, un ticket => un seul client,
-- même si 50 paiements arrivent en même temps ou si le webhook arrive 3 fois.
create or replace function assign_ticket(p_payment uuid, p_method text)
returns text language plpgsql as $$
declare
  pay payments%rowtype;
  t   tickets%rowtype;
begin
  select * into pay from payments where id = p_payment for update;
  if not found then return null; end if;
  if pay.ticket_id is not null then
    return (select code from tickets where id = pay.ticket_id);
  end if;

  select * into t from tickets
   where zone_id = pay.zone_id and pricing_id = pay.pricing_id and status = 'free' and channel = 'online'
   order by id limit 1
   for update skip locked;

  if not found then
    update payments set status = 'paid_no_stock', method = p_method, completed_at = now()
     where id = p_payment;
    return null;
  end if;

  update tickets set status = 'sold', payment_id = p_payment, sold_at = now() where id = t.id;
  update payments set status = 'success', ticket_id = t.id, method = p_method, completed_at = now()
   where id = p_payment;
  return t.code;
end $$;

-- Vue comptable simple
create or replace view ventes_par_jour as
select zone_id, date_trunc('day', completed_at)::date as jour, pricing_label,
       count(*) as tickets, sum(amount) as total_fcfa
  from payments where status = 'success'
 group by 1,2,3 order by 2 desc;

-- La base n'est accessible que par le serveur (pas d'accès public via l'API Supabase)
alter table zones    enable row level security;
alter table pricings enable row level security;
alter table tickets  enable row level security;
alter table payments enable row level security;
