# =====================================================================
#  SYNCHRONISATION AUTOMATIQUE DES TICKETS  (MikroTik  <-  serveur)
#
#  Pourquoi : Starlink est en CGNAT, ton serveur ne peut PAS joindre le
#  routeur depuis internet. C'est donc le routeur qui va chercher, toutes
#  les 2 minutes, les nouveaux tickets générés par le serveur, les crée
#  dans /ip hotspot user, puis confirme. Le serveur ne vend QUE des
#  tickets confirmés par le routeur => jamais de ticket vendu-mais-refusé.
#
#  Plus besoin d'importer des CSV à la main : le stock se remplit seul.
#
#  Remplace ZONE_ID et ROUTER_TOKEN par les valeurs affichées par le
#  serveur (commande : npm run zone:create), puis colle dans le Terminal.
# =====================================================================

:global SYNCURL "https://wifi-zone-production.up.railway.app/api/router/sync?zone=02a78989-c240-4dd4-b724-b1e30e93dd27&token=ROUTER_TOKEN"

# Faire confiance aux certificats HTTPS publics (RouterOS 7.19+)
:do { /certificate settings set builtin-trust-anchors=trusted } on-error={}

/system script add name=sync-tickets policy=read,write,test,policy source={
  :global SYNCURL
  :do {
    /tool fetch url=$SYNCURL mode=https check-certificate=yes dst-path=sync.rsc output=file
    :delay 1s
    :if ([:len [/file find name=sync.rsc]] > 0) do={
      /import file-name=sync.rsc verbose=no
      /file remove sync.rsc
    }
  } on-error={ :log warning "sync-tickets : serveur injoignable (Starlink coupe ?)" }
}
/system scheduler add name=sync-tickets interval=2m on-event=sync-tickets start-time=startup

# Premier lancement immédiat
/system script run sync-tickets
