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
#  Remplace ROUTER_TOKEN par le router_token de ta zone (Supabase > zones),
#  dans une COPIE PRIVÉE de ce fichier (jamais sur GitHub), puis importe-la.
#  On peut réimporter ce fichier sans risque : il remplace l'ancienne version.
#  Nouveau jeton plus tard ? Réimporte simplement la copie corrigée.
# =====================================================================

:global SYNCURL "https://wifi-zone-production.up.railway.app/api/router/sync?zone=02a78989-c240-4dd4-b724-b1e30e93dd27&token=ROUTER_TOKEN"

# Faire confiance aux certificats HTTPS publics (RouterOS 7.19+)
:do { /certificate settings set builtin-trust-anchors=trusted } on-error={}

# On repart propre si le fichier a déjà été importé
:do { /system scheduler remove [find name=sync-tickets] } on-error={}
:do { /system script remove [find name=sync-tickets] } on-error={}

# L'adresse est rangée dans le commentaire du script : elle survit aux redémarrages.
# En cas d'échec, le Log affiche la VRAIE erreur (403 = jeton refusé, etc.).
/system script add name=sync-tickets comment=$SYNCURL policy=read,write,test,policy source={
  :local url [/system script get [find name="sync-tickets"] comment]
  :local ok true
  :do { /file remove [find name="sync.rsc"] } on-error={}
  :onerror err in={
    /tool fetch url=$url mode=https check-certificate=yes dst-path=sync.rsc output=file
  } do={
    :set ok false
    :log warning ("sync-tickets : telechargement impossible : " . $err)
  }
  :if ($ok) do={
    :delay 1s
    :if ([:len [/file find name="sync.rsc"]] > 0) do={
      :onerror err in={ /import file-name=sync.rsc verbose=no } do={
        :log warning ("sync-tickets : import impossible : " . $err)
      }
      :do { /file remove [find name="sync.rsc"] } on-error={}
    }
  }
}

/system scheduler add name=sync-tickets interval=2m on-event=sync-tickets start-time=startup

# Premier lancement immédiat
/system script run sync-tickets
:log info "sync-tickets installe. Verifie : /ip hotspot user print count-only"
