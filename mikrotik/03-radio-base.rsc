# =====================================================================
#  RADIO BASE (site central, sur le mât à côté du Starlink)
#  Modèle : MikroTik OmniTIK 5 ac   (site central AU MILIEU du village)
#       ou  MikroTik mANTBox 52 15s (site central EN BORDURE : secteur 90°/120°
#            orienté vers le village)
#  Rôle  : émet la dorsale 5 GHz vers les quartiers (point-multipoint)
#  Branché sur : ether2 du hAP ac³ (ou switch PoE) — alimenté en PoE
#
#  1. Reset à vide : /system reset-configuration no-defaults=yes skip-backup=yes
#  2. Connexion WinBox par l'adresse MAC, modifie les variables, colle tout.
# =====================================================================
:global NOM     "BASE-CENTRE"
:global ADMINPW "ChangeMoi-Base!"
:global BBSSID  "DORSALE-VILLAGE"
:global BBKEY   "UneCleTresLongueEtSecrete2026"   ;# identique sur TOUTES les stations
:global MYIP    "10.10.0.2/22"
:global FREQ    5180   ;# canal 5 GHz : choisis le moins encombré (Tools > Frequency Usage)

/user set admin password=$ADMINPW
/system identity set name=$NOM

/interface bridge add name=br protocol-mode=none
/interface bridge port add bridge=br interface=ether1

/interface wireless security-profiles add name=dorsale mode=dynamic-keys \
    authentication-types=wpa2-psk unicast-ciphers=aes-ccm group-ciphers=aes-ccm \
    wpa2-pre-shared-key=$BBKEY
/interface wireless set [find default-name=wlan1] mode=ap-bridge ssid=$BBSSID \
    band=5ghz-a/n/ac channel-width=20/40mhz-Ce frequency=$FREQ \
    wireless-protocol=nv2 nv2-security=enabled nv2-preshared-key=$BBKEY \
    security-profile=dorsale hide-ssid=yes wps-mode=disabled \
    installation=outdoor disabled=no
/interface bridge port add bridge=br interface=wlan1

/ip address add address=$MYIP interface=br
/ip route add gateway=10.10.0.1
/ip dns set servers=10.10.0.1
/system ntp client set enabled=yes servers=10.10.0.1
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes
:log info "Base dorsale prete"
