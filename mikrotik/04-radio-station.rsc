# =====================================================================
#  RADIO STATION DE QUARTIER (1 par quartier)
#  Modèle : MikroTik SXTsq 5 ac (≤ 1,5 km)  ou  LHG 5 ac (> 1,5 km / arbres)
#  Rôle  : reçoit la dorsale 5 GHz et la passe au switch PoE du quartier
#  Orientation : pointer précisément vers la base (aligner avec le signal)
#
#  Change NOM et MYIP pour chaque quartier :
#    Quartier 1 -> 10.10.0.11   Quartier 2 -> 10.10.0.12  ...  Quartier 6 -> 10.10.0.16
# =====================================================================
:global NOM     "STA-Q1-MARCHE"
:global ADMINPW "ChangeMoi-Station!"
:global BBSSID  "DORSALE-VILLAGE"
:global BBKEY   "UneCleTresLongueEtSecrete2026"   ;# la même que sur la base
:global MYIP    "10.10.0.11/22"

/user set admin password=$ADMINPW
/system identity set name=$NOM

/interface bridge add name=br protocol-mode=none
/interface bridge port add bridge=br interface=ether1

/interface wireless security-profiles add name=dorsale mode=dynamic-keys \
    authentication-types=wpa2-psk unicast-ciphers=aes-ccm group-ciphers=aes-ccm \
    wpa2-pre-shared-key=$BBKEY
# station-bridge = pont transparent : les clients du quartier arrivent
# directement sur le hotspot du routeur central (même portail captif)
/interface wireless set [find default-name=wlan1] mode=station-bridge ssid=$BBSSID \
    band=5ghz-a/n/ac channel-width=20/40mhz-Ce frequency=auto \
    wireless-protocol=nv2 nv2-security=enabled nv2-preshared-key=$BBKEY \
    security-profile=dorsale installation=outdoor disabled=no
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

# Vérif de l'alignement : Wireless > Registration -> "Signal Strength"
#   -50 à -65 dBm = excellent, -65 à -72 = correct, pire que -75 = réoriente / monte le mât
:log info "Station prete - verifier le signal dans Wireless > Registration"
