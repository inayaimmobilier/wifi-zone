# =====================================================================
#  POINT D'ACCÈS EXTÉRIEUR CLIENTS (2,4 GHz) — 1 ou 2 par quartier
#  Modèle : MikroTik mANTBox 2 12s (secteur 120°, portée téléphone ~200-300 m)
#  Branché sur : switch PoE du quartier (hEX PoE lite), derrière la station
#
#  Change NOM, MYIP et FREQ pour chaque AP :
#    IP : 10.10.0.21 à 10.10.0.36
#    FREQ : alterne 2412 (canal 1), 2437 (canal 6), 2462 (canal 11)
#           -> deux AP qui se « voient » ne doivent JAMAIS avoir le même canal
# =====================================================================
:global NOM     "AP-Q1-MARCHE"
:global ADMINPW "ChangeMoi-AP!"
:global SSID    "VILLAGE-WIFI"     ;# identique au hAP ac³ et aux LB-Link
:global MYIP    "10.10.0.21/22"
:global FREQ    2412

/user set admin password=$ADMINPW
/system identity set name=$NOM

/interface bridge add name=br protocol-mode=none
/interface bridge port add bridge=br interface=ether1

/interface wireless security-profiles add name=ouvert mode=none
# default-forwarding=no : les clients ne peuvent pas se voir entre eux (sécurité)
/interface wireless set [find default-name=wlan1] mode=ap-bridge ssid=$SSID \
    band=2ghz-b/g/n channel-width=20mhz frequency=$FREQ \
    wireless-protocol=802.11 security-profile=ouvert default-forwarding=no \
    max-station-count=60 installation=outdoor wps-mode=disabled disabled=no
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
:log info "AP exterieur pret"
