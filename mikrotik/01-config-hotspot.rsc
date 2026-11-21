# =====================================================================
#  WI-FI ZONE VILLAGE — Configuration MikroTik (RouterOS v7)
#  Routeur cœur : MikroTik hAP ac³ (ou hAP ax², hEX + AP...)
#  Internet    : Starlink (routeur Starlink en mode BYPASS) sur ether1
#
#  AVANT DE COLLER :
#   1. Reset sans config par défaut :  /system reset-configuration no-defaults=yes skip-backup=yes
#   2. Connecte-toi avec Winbox via l'adresse MAC (onglet Neighbors).
#   3. Modifie les VARIABLES ci-dessous, puis colle TOUT le fichier
#      dans Winbox > New Terminal (ou : Files > glisser le .rsc, puis
#      /import file-name=01-config-hotspot.rsc).
# =====================================================================

:global ZONENAME   "VILLAGE-WIFI"          ;# Nom du Wi-Fi (SSID)
:global DNSNAME    "login.wifi"            ;# Adresse du portail (ne doit PAS exister sur internet)
:global ADMINPASS  "ChangeMoi-Tres-Long!"  ;# Mot de passe admin du routeur
:global APIDOMAIN  "wifi-zone-production.up.railway.app"   ;# Ton serveur de paiement (backend)
:global SITEDOMAIN "wifi-zone-production.up.railway.app"   ;# Ton site d'achat

# ---------- 1. Sécurité de base ----------
/user set admin password=$ADMINPASS
/system identity set name=$ZONENAME
/system clock set time-zone-name=Africa/Abidjan
/system ntp client set enabled=yes
/system ntp client servers add address=pool.ntp.org

# ---------- 2. Bridge HOTSPOT (tous les ports LAN + Wi-Fi) ----------
/interface bridge add name=HOTSPOT comment="Clients Wi-Fi" igmp-snooping=no
/interface bridge port
add bridge=HOTSPOT interface=ether2 comment="Backbone / AP LB-Link"
add bridge=HOTSPOT interface=ether3 comment="PC gestion / AP"
add bridge=HOTSPOT interface=ether4 comment="AP"
add bridge=HOTSPOT interface=ether5 comment="AP / PoE out"
# ether1 = Starlink : JAMAIS dans le bridge

/interface list add name=WAN
/interface list add name=LAN
/interface list member add list=WAN interface=ether1
/interface list member add list=LAN interface=HOTSPOT

# ---------- 3. Wi-Fi intégré du hAP ac³ (driver "wireless" classique) ----------
# Réseau OUVERT (sans mot de passe) : c'est le portail qui protège.
# Si ton modèle utilise le menu "WiFi" (hAP ax), configure-le dans Winbox :
# SSID identique, canal 20 MHz, bridge HOTSPOT.
:do {
  /interface wireless security-profiles add name=ouvert mode=none
  /interface wireless set [find default-name=wlan1] mode=ap-bridge ssid=$ZONENAME \
      band=2ghz-b/g/n channel-width=20mhz frequency=2437 security-profile=ouvert \
      default-forwarding=no wps-mode=disabled disabled=no
  /interface wireless set [find default-name=wlan2] mode=ap-bridge ssid=$ZONENAME \
      band=5ghz-a/n/ac channel-width=20/40mhz-Ce security-profile=ouvert \
      default-forwarding=no wps-mode=disabled disabled=no
  /interface bridge port add bridge=HOTSPOT interface=wlan1
  /interface bridge port add bridge=HOTSPOT interface=wlan2
} on-error={ :log warning "Pas de wireless classique : configure le menu WiFi a la main" }

# ---------- 4. Adresses : /22 = jusqu'à ~1000 appareils ----------
/ip address add address=10.10.0.1/22 interface=HOTSPOT comment="Passerelle clients"
/ip pool add name=pool-clients ranges=10.10.0.50-10.10.3.250
# 10.10.0.2 -> 10.10.0.49 réservé aux équipements (AP LB-Link, liaisons radio)

# ---------- 5. Internet Starlink (DHCP sur ether1) ----------
/ip dhcp-client add interface=ether1 use-peer-dns=no add-default-route=yes \
    default-route-distance=1 comment="Starlink bypass"

# ---------- 6. DHCP pour les clients ----------
/ip dhcp-server add name=dhcp-clients interface=HOTSPOT address-pool=pool-clients \
    lease-time=30m always-broadcast=yes add-arp=yes
/ip dhcp-server network add address=10.10.0.0/22 gateway=10.10.0.1 dns-server=10.10.0.1

# ---------- 7. DNS (le routeur sert de cache DNS) ----------
/ip dns set servers=1.1.1.1,8.8.8.8 allow-remote-requests=yes cache-size=8192KiB

# ---------- 8. NAT ----------
/ip firewall nat add chain=srcnat out-interface-list=WAN action=masquerade comment="Sortie internet"

# ---------- 9. Pare-feu : protège le routeur ----------
/ip firewall filter
add chain=input action=accept connection-state=established,related,untracked comment="OK etabli"
add chain=input action=drop connection-state=invalid
add chain=input action=accept protocol=icmp
add chain=input action=drop in-interface-list=WAN comment="Rien depuis internet"
add chain=forward action=accept connection-state=established,related,untracked
add chain=forward action=drop connection-state=invalid
add chain=forward action=drop connection-state=new connection-nat-state=!dstnat in-interface-list=WAN

# ---------- 10. Anti-partage de connexion (TTL=1) ----------
/ip firewall mangle add chain=postrouting out-interface=HOTSPOT action=change-ttl \
    new-ttl=set:1 passthrough=yes comment="Anti partage de connexion"

# ---------- 11. Services : on ferme tout sauf Winbox + API locale ----------
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set ssh port=2222
set api-ssl disabled=yes
set api address=10.10.0.0/22
set winbox address=10.10.0.0/22
/tool mac-server set allowed-interface-list=LAN
/tool mac-server mac-winbox set allowed-interface-list=LAN
/ip neighbor discovery-settings set discover-interface-list=LAN

# ---------- 12. HOTSPOT (portail captif) ----------
/ip hotspot profile add name=hsprof-village hotspot-address=10.10.0.1 dns-name=$DNSNAME \
    html-directory=hotspot login-by=http-chap,http-pap,cookie http-cookie-lifetime=1d \
    use-radius=no
/ip hotspot add name=hotspot1 interface=HOTSPOT address-pool=pool-clients \
    profile=hsprof-village addresses-per-mac=2 idle-timeout=5m disabled=no
# Les équipements réseau (radios, AP, LB-Link : 10.10.0.2 à .49) passent sans ticket
:for i from=2 to=49 do={
  /ip hotspot ip-binding add address=("10.10.0." . $i) type=bypassed comment="Equipement reseau"
}

# ---------- 13. Forfaits (profils). Le NOM doit être identique dans le backend ----------
# rate-limit = débit montant/descendant par client. Starlink ~100 Mbit/s partagés.
/ip hotspot user profile
add name=1H    shared-users=1 rate-limit=1M/3M  keepalive-timeout=2m status-autorefresh=1m
add name=24H   shared-users=1 rate-limit=1M/4M  keepalive-timeout=2m status-autorefresh=1m
add name=7J    shared-users=1 rate-limit=2M/5M  keepalive-timeout=2m status-autorefresh=1m
add name=30J   shared-users=2 rate-limit=2M/6M  keepalive-timeout=2m status-autorefresh=1m
# La durée de chaque ticket = limit-uptime posé par le backend (voir 02-sync-tickets.rsc).

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
