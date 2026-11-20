-- =====================================================================
--  Crée ta zone Wi-Fi + les 4 forfaits  (Supabase > SQL Editor > Run)
--  À lancer UNE SEULE FOIS, après schema.sql.
--  Modifie le nom et le numéro WhatsApp si besoin.
-- =====================================================================
with z as (
  insert into zones (name, country, dial_code, methods, support_phone)
  values ('VILLAGE WI-FI', 'CI', '225',
          array['orange_ci','mtn_ci','moov_ci','wave_ci'],
          '2250700000000')
  returning id
), p as (
  insert into pricings (zone_id, profile, label, price, uptime, sort)
  select z.id, f.profile, f.label, f.price, f.uptime, f.sort
    from z, (values
      ('1H',  '1 heure',   100,  '1h',  1),
      ('24H', '24 heures', 200,  '1d',  2),
      ('7J',  '7 jours',   1000, '7d',  3),
      ('30J', '30 jours',  3000, '30d', 4)
    ) as f(profile, label, price, uptime, sort)
  returning zone_id
)
select distinct zones.id as zone_id, zones.router_token
  from p join zones on zones.id = p.zone_id;
-- Le résultat affiche ZONE_ID et ROUTER_TOKEN : note-les (le token est SECRET).
-- Tu peux les revoir plus tard : Table Editor > zones.
