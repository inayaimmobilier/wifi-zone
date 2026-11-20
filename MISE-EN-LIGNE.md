# Mise en ligne : checklist pas à pas

Le code est déjà sur GitHub, dans le dépôt privé **inayaimmobilier/wifi-zone**.
Coche chaque étape dans l'ordre. Ne colle **jamais** tes clés ou mots de passe dans une conversation :
tu les tapes seulement sur Supabase, Render et Moneroo.

---

## Étape 1 : Supabase (la base de données) · 10 min

- [ ] Va sur **supabase.com** et crée ton nouveau compte (de préférence avec un e-mail dédié au projet).
- [ ] **New project**
  - Nom : `wifi-zone`
  - Région : **Paris (eu-west-3)**, la plus proche de la Côte d'Ivoire
  - **Database password** : génère-le avec le bouton *Generate* et **garde-le dans un endroit sûr**.
    Tu en as besoin à l'étape 3.
- [ ] Attends 2 minutes que le projet soit prêt.
- [ ] Menu de gauche → **SQL Editor** → *New query* → colle **tout** le fichier `backend/schema.sql` → **Run**.
  Le message attendu est « Success. No rows returned ».
- [ ] Nouvelle requête → colle `backend/seed-zone.sql` → **Run**.
  Le résultat affiche **zone_id** et **router_token**. Recopie-les dans un bloc-notes.
- [ ] Bouton **Connect** (en haut) → onglet *Connection string* → choisis **Session pooler** → copie l'adresse
  `postgresql://postgres.xxxx:[YOUR-PASSWORD]@aws-...pooler.supabase.com:5432/postgres`.
  Remplace `[YOUR-PASSWORD]` par ton mot de passe de base de données : c'est ton **DATABASE_URL**.

## Étape 2 : Moneroo (le paiement) · 10 min, puis 1 à 5 jours de vérification

- [ ] Va sur **moneroo.io**, crée le compte et lance tout de suite la **vérification KYC** (pièce d'identité, activité).
- [ ] *Developers → API Keys* : copie la **clé secrète de test** (elle commence par `test_` ou `pvk_sandbox`).
- [ ] Dans les réglages de paiement, active **Orange Money CI, MTN CI, Moov CI et Wave CI**.
- [ ] Le webhook se configure à l'étape 4, quand ton adresse Render existera.

## Étape 3 : Render (l'hébergement) · 10 min · ~7 $/mois

- [ ] Va sur **render.com** → *Sign up with GitHub* (compte **inayaimmobilier**).
- [ ] **New → Blueprint** → autorise Render à lire le dépôt **wifi-zone** → *Connect*.
  Render lit le fichier `render.yaml` et prépare le service **wifi-zone** (plan Starter, Francfort).
- [ ] Render te demande les valeurs secrètes :
  | Variable | Valeur |
  |---|---|
  | `DATABASE_URL` | l'adresse de l'étape 1 (avec ton mot de passe) |
  | `MONEROO_SECRET_KEY` | la clé de test Moneroo |
  | `MONEROO_WEBHOOK_SECRET` | mets `a-remplacer` pour l'instant (étape 4) |
  | `ADMIN_PASSWORD` | un mot de passe long pour ton tableau de bord |
- [ ] **Apply** et attends que le déploiement soit **Live** (vert).
- [ ] Note l'adresse affichée en haut, par exemple `https://wifi-zone-ab12.onrender.com`.
  C'est **TON_ADRESSE** dans la suite de cette checklist.
- [ ] Ouvre `TON_ADRESSE/api/health` : tu dois voir `{"status":"ok"}`.
- [ ] Ouvre `TON_ADRESSE/admin.html`, connecte-toi : le tableau de bord de **VILLAGE WI-FI** s'affiche.

## Étape 4 : Webhook Moneroo · 5 min

- [ ] Moneroo → *Developers → Webhooks* → **Add**
  - URL : `TON_ADRESSE/api/moneroo/webhook`
  - Événements : `payment.success`, `payment.failed`, `payment.cancelled`
- [ ] Copie le **secret de signature** → Render → service wifi-zone → *Environment* →
  `MONEROO_WEBHOOK_SECRET` = ce secret → *Save* (Render redéploie tout seul).
- [ ] **Test** : ouvre `TON_ADRESSE/acheter.html?zone=ZONE_ID`. Les forfaits s'affichent mais restent
  « épuisés » tant que le routeur n'est pas branché (étape 5). C'est normal.

## Étape 5 : le routeur MikroTik

Dans les fichiers ci-dessous, remplace `mazone.com` par l'hôte de TON_ADRESSE (sans `https://`),
par exemple `wifi-zone-ab12.onrender.com`.

- [ ] `mikrotik/01-config-hotspot.rsc` : les variables `SITEDOMAIN` et `APIDOMAIN` prennent **toutes les deux** cet hôte.
- [ ] `mikrotik/02-sync-tickets.rsc` :
  `https://wifi-zone-ab12.onrender.com/api/router/sync?zone=ZONE_ID&token=ROUTER_TOKEN`
- [ ] `hotspot/login.html` : remplace `mazone.com`, `ZONE_ID` et le numéro WhatsApp.
- [ ] Applique le guide `GUIDE-PROJET.md` §4 : reset, import de `01`, envoi du dossier `hotspot`, import de `02`.
- [ ] Au bout de 2 minutes, le tableau de bord affiche **Routeur : En ligne** et du stock pour chaque forfait.

## Étape 6 : le test complet (mode test Moneroo)

- [ ] Téléphone sur le Wi-Fi → le portail s'ouvre → **Acheter un ticket** → 100 F → passerelle de démonstration Moneroo.
- [ ] Le code s'affiche → **Me connecter maintenant** → internet fonctionne.
- [ ] La vente apparaît dans le tableau de bord.

## Étape 7 : passer en vrai (quand le KYC Moneroo est validé)

- [ ] Render → `MONEROO_SECRET_KEY` = la **clé de production**.
- [ ] Moneroo en mode production : vérifie le webhook et son secret (il peut être différent du secret de test).
- [ ] Achète un vrai ticket de 100 F avec ton propre numéro, pour **chaque** opérateur (Orange, MTN, Moov, Wave).
- [ ] Imprime l'affiche (tableau de bord → 🪧) et ouvre au public 🎉

---

### Plus tard : ton propre nom de domaine
Achète par exemple `villagewifi.ci` ou `.com`. Ensuite :
- Render → *Settings → Custom Domains* : ajoute le domaine et crée chez ton registraire l'enregistrement DNS indiqué.
- Render → *Environment* : `PUBLIC_URL=https://tondomaine.com`.
- Moneroo : mets à jour l'URL du webhook.
- MikroTik et `login.html` : remplace l'ancien hôte par le nouveau domaine.

### Mettre à jour la plateforme
Chaque `git push` sur la branche `main` redéploie Render automatiquement.
