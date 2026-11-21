# Mise en ligne : checklist pas à pas

Paiement : **CinetPay**. Hébergement : **Railway**. Base de données : **Supabase**.
Le code est dans le dépôt GitHub **inayaimmobilier/wifi-zone**.

Ne colle **jamais** tes clés ou mots de passe dans une conversation : tu les tapes seulement sur
Supabase, Railway et CinetPay.

> 💡 La connexion internet de ton PC coupe souvent. Si un site ne charge pas, essaie depuis ton
> téléphone en 4G (partage de connexion) ou à un autre moment de la journée.

---

## Étape 1 : Supabase (la base de données) · 10 min · ✅ compte créé

- [ ] **New project**
  - Nom : `wifi-zone`
  - Région : **Paris (eu-west-3)**
  - **Database password** : clique sur *Generate* et **garde-le dans un endroit sûr**.
- [ ] Attends 2 minutes que le projet soit prêt.
- [ ] **SQL Editor** → *New query* → colle **tout** `backend/schema.sql` → **Run**.
  Le message attendu est « Success. No rows returned ».
- [ ] *New query* → colle `backend/seed-zone.sql` → **Run**.
  Le résultat affiche **zone_id** et **router_token** : recopie-les (le token est secret).
- [ ] Bouton **Connect** (en haut) → *Session pooler* → copie l'adresse
  `postgresql://postgres.xxxx:[YOUR-PASSWORD]@aws-...pooler.supabase.com:5432/postgres`.
  Remplace `[YOUR-PASSWORD]` par ton mot de passe : c'est ton **DATABASE_URL**.

## Étape 2 : CinetPay (le paiement) · 15 min, puis quelques jours de vérification

- [ ] Va sur **cinetpay.com** → *Créer un compte marchand*. Lance tout de suite la vérification KYC
  (pièce d'identité ; RCCM si tu as une entreprise).
- [ ] Dans ton espace marchand, trouve les **identifiants API** :
  - une **clé API** qui commence par `sk_test_` (mode test) ;
  - le **mot de passe API** qui va avec.
- [ ] Vérifie que **Orange Money, MTN MoMo, Moov Money et Wave (Côte d'Ivoire)** sont activés.
- [ ] ⚠️ Si ton espace te donne plutôt une **« apikey » et un « site_id »** (ancienne API CinetPay) :
  **arrête-toi ici et dis-le-moi**. Le code doit être adapté.

Rien d'autre à configurer chez CinetPay : le serveur lui donne lui-même son adresse de notification.

## Étape 3 : Railway (l'hébergement) · 10 min · ~5 $/mois

- [ ] **railway.com** → *Login* → **Continue with GitHub** (compte **inayaimmobilier**).
- [ ] **New Project** → **Deploy from GitHub repo** → choisis **wifi-zone**.
  Si le dépôt n'apparaît pas : *Configure GitHub App* → autorise **wifi-zone** → reviens.
- [ ] Clique sur le service créé → onglet **Settings** → **Source** → **Root Directory** : `backend`.
  (Le premier déploiement peut échouer avant ce réglage : c'est normal.)
- [ ] Onglet **Variables** → **Raw Editor**, colle puis remplis :
  ```
  DATABASE_URL=
  CINETPAY_API_KEY=a-remplacer
  CINETPAY_API_PASSWORD=a-remplacer
  ADMIN_PASSWORD=
  STOCK_TARGET=60
  COMMISSION_PERCENT=3
  ```
  → **Update Variables**. (Les vraies clés CinetPay viendront après la validation du compte.)
- [ ] **Settings** → **Networking** → **Generate Domain** → accepte le port proposé.
  Tu obtiens une adresse comme `https://wifi-zone-production-ab12.up.railway.app` : c'est **TON_ADRESSE**.
- [ ] **Settings** → **Deploy** → **Healthcheck Path** : `/api/health`.
- [ ] Onglet **Deployments** : attends **Active** (vert), sinon clique **Deploy**.
- [ ] Ouvre `TON_ADRESSE/api/health`. Tu dois voir `{"status":"ok","paiement":"bac a sable"}`.
- [ ] Ouvre `TON_ADRESSE/admin.html` et connecte-toi : le tableau de bord de **VILLAGE WI-FI** s'affiche.

## Étape 4 : le routeur MikroTik

Remplace `mazone.com` par l'hôte de TON_ADRESSE (sans `https://`), par exemple `wifi-zone-production-ab12.up.railway.app` :

- [ ] `mikrotik/01-config-hotspot.rsc` : les variables `SITEDOMAIN` **et** `APIDOMAIN` prennent cet hôte.
- [ ] `mikrotik/02-sync-tickets.rsc` :
  `https://wifi-zone-production-ab12.up.railway.app/api/router/sync?zone=ZONE_ID&token=ROUTER_TOKEN`
- [ ] `hotspot/login.html` : remplace `mazone.com`, `ZONE_ID` et le numéro WhatsApp.
- [ ] Applique `GUIDE-PROJET.md` §4 : reset, import de `01`, envoi du dossier `hotspot`, import de `02`.
- [ ] Au bout de 2 minutes, le tableau de bord affiche **Routeur : En ligne** et du stock pour chaque forfait.

## Étape 5 : le test complet (clé de test CinetPay)

- [ ] Téléphone sur le Wi-Fi → le portail s'ouvre → **Acheter un ticket** → la page CinetPay s'ouvre.
  Si elle reste bloquée : MikroTik → *IP → Hotspot → Hosts* → note le domaine bloqué → ajoute-le au walled garden.
- [ ] Paie avec le mode test → le code s'affiche → **Me connecter maintenant** → internet fonctionne.
- [ ] La vente apparaît dans le tableau de bord.

## Étape 6 : passer en vrai (quand le KYC CinetPay est validé)

- [ ] Railway → *Variables* : remplace la clé par ta **clé de production** `sk_live_...` (et son mot de passe).
  Le serveur passe tout seul sur l'API de production. `/api/health` affiche alors `"paiement":"production"`.
- [ ] Achète un vrai ticket de 100 F avec ton propre numéro, pour **chaque** opérateur (Orange, MTN, Moov, Wave).
- [ ] Imprime l'affiche (tableau de bord → 🪧) et ouvre au public 🎉

---

### Plus tard : ton propre nom de domaine
- Railway → *Settings → Networking → Custom Domain* : ajoute le domaine et crée chez ton registraire l'enregistrement DNS indiqué.
- Railway → *Variables* : `PUBLIC_URL=https://tondomaine.com`.
- MikroTik et `login.html` : remplace l'ancien hôte par le nouveau domaine.

### Mettre à jour la plateforme
Chaque `git push` sur la branche `main` redéploie Railway automatiquement.
