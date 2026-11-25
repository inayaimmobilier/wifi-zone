# =====================================================================
#  WI-FI ZONE VILLAGE — SUITE de 01-config-hotspot.rsc (sections 14 à 17)
#  À utiliser seulement si l'import de 01 s'est arrêté avant la fin
#  (par exemple à cause du "device-mode home" des MikroTik récents).
#  Aucun secret dans ce fichier : on peut l'importer tel quel.
#     /import file-name=01b-suite-config.rsc
# =====================================================================

:global APIDOMAIN  "wifi-zone-production.up.railway.app"
:global SITEDOMAIN "wifi-zone-production.up.railway.app"

# On repart propre si une partie existe déjà
:do { /system scheduler remove [find name=nettoyer-tickets] } on-error={}
:do { /system script remove [find name=nettoyer-tickets] } on-error={}
:do { /ip hotspot walled-garden remove [find] } on-error={}
:do { /ip hotspot walled-garden ip remove [find dynamic=no] } on-error={}
:do { /queue simple remove [find name=TOTAL-VILLAGE] } on-error={}
:do { /queue type remove [find name~"^pcq-(down|up)\$"] } on-error={}
:do { /tool netwatch remove [find host=1.1.1.1] } on-error={}

# ---------- 14. Nettoyage des tickets épuisés ----------
# Chaque ticket est créé avec limit-uptime (temps de connexion réel : 1h, 1d, 7d, 30d).
# Quand le temps est consommé, le routeur refuse la connexion ; ce script
# supprime ensuite les tickets épuisés toutes les 15 minutes.
/system script add name=nettoyer-tickets policy=read,write,test source={
  :foreach id in=[/ip hotspot user find where limit-uptime>0 and comment~"^auto"] do={
    :if ([/ip hotspot user get $id uptime] >= [/ip hotspot user get $id limit-uptime]) do={
      :log info ("Ticket epuise supprime : " . [/ip hotspot user get $id name])
      /ip hotspot user remove $id
    }
  }
}
/system scheduler add name=nettoyer-tickets interval=15m on-event=nettoyer-tickets

# ---------- 15. Walled garden : ce qui marche SANS ticket ----------
# Indispensable pour que le client puisse PAYER avant d'avoir internet.
/ip hotspot walled-garden
add dst-host=$SITEDOMAIN action=allow comment="Site achat"
add dst-host=("*." . $SITEDOMAIN) action=allow comment="Site achat"
add dst-host=*.cinetpay.com action=allow comment="CinetPay"
add dst-host=*.cinetpay.co action=allow comment="CinetPay"
add dst-host=*.cinetpay.net action=allow comment="CinetPay (bac a sable)"
add dst-host=*.wave.com action=allow comment="Wave"
add dst-host=wa.me action=allow comment="WhatsApp support"
/ip hotspot walled-garden ip
add action=accept dst-host=$SITEDOMAIN comment="HTTPS site achat"
add action=accept dst-host=("www." . $SITEDOMAIN) comment="HTTPS site achat"
add action=accept dst-host=$APIDOMAIN comment="HTTPS API"
add action=accept dst-host=cinetpay.com comment="HTTPS CinetPay"
add action=accept dst-host=checkout.cinetpay.com comment="HTTPS CinetPay"
add action=accept dst-host=api.cinetpay.co comment="HTTPS CinetPay"
add action=accept dst-host=api.cinetpay.net comment="HTTPS CinetPay test"
# Si la page de paiement reste bloquee : IP > Hotspot > Hosts, note le domaine bloque et ajoute-le ici
add action=accept dst-host=pay.wave.com comment="HTTPS Wave"
add action=accept dst-host=wa.me comment="WhatsApp"
add action=accept dst-host=api.whatsapp.com comment="WhatsApp"

# ---------- 16. Partage équitable de la bande passante (PCQ) ----------
/queue type
add name=pcq-down kind=pcq pcq-classifier=dst-address pcq-rate=0
add name=pcq-up   kind=pcq pcq-classifier=src-address pcq-rate=0
/queue simple add name=TOTAL-VILLAGE target=10.10.0.0/22 queue=pcq-up/pcq-down \
    max-limit=15M/90M comment="Ajuste a 90% du debit Starlink mesure"

# ---------- 17. Surveillance Starlink ----------
/tool netwatch add host=1.1.1.1 interval=30s \
    down-script=":log error \"INTERNET COUPE (Starlink)\"" \
    up-script=":log info \"Internet retabli\""

:log info "Configuration Wi-Fi Zone terminee. Importe maintenant 02-sync-tickets.rsc"
