# Wi-Fi Zone Village — Guide complet de A à Z

Starlink + MikroTik + points d'accès + paiement Mobile Money + tickets automatiques.

---

## 0. Comment ça marche

```
                   ☁ Internet
                       │
               [Antenne Starlink]
                       │  (câble Starlink)
          [Routeur Starlink en mode BYPASS]
                       │ ether1 (WAN)
        ┌──────[MikroTik hAP ac³ : HOTSPOT]──────┐   ← portail captif, tickets, débits
        │ ether2      ether3      ether4/5       │ Wi-Fi intégré
        │                                        │
  [Switch PoE] ──► liaisons radio extérieures ──► quartiers du village
        │                │                    │
   [AP LB-Link]   [AP extérieur A]      [AP extérieur B] ...
   (boutique)     (place du marché)     (école / mosquée / église)
```

**Le parcours du client :**
1. Il se connecte au Wi-Fi « VILLAGE WI-FI » → la page du portail s'ouvre toute seule.
2. Il touche **« Acheter un ticket »** → il choisit 1 h / 24 h / 7 j / 30 j et saisit son numéro.
3. Moneroo affiche Orange Money / MTN / Moov / Wave → il valide sur son téléphone.
4. Moneroo prévient ton serveur (webhook signé) → le serveur attribue un ticket **en une seule opération**.
5. Le code s'affiche → bouton **« Me connecter maintenant »** → internet est ouvert. Aucun geste de ta part.

**Ce que j'ai ajouté par rapport à ta formation :** dans la formation, il faut générer les tickets
et les importer DEUX fois (routeur + plateforme). Ici, le MikroTik va chercher tout seul ses tickets
sur ton serveur toutes les 2 minutes (`02-sync-tickets.rsc`). Le serveur ne vend que les tickets que
le routeur a confirmés. Résultat : **plus aucun import manuel, et jamais de ticket vendu mais refusé.**
Ça marche aussi derrière Starlink, qui bloque les connexions entrantes (CGNAT).

---

## 1. Le matériel

### Ce que tu as déjà

| Matériel | Rôle | À savoir |
|---|---|---|
| **MikroTik hAP ac³** (photo noire) | Cœur du réseau : portail captif, tickets, partage du débit | Wi-Fi 2,4 + 5 GHz intégré, couvre seulement ~30–50 m. 5 ports Gigabit, ether1 sert d'entrée internet. |
| **LB-Link BL-WR2000** (photo blanche) | Point d'accès secondaire **en intérieur** (boutique, maison, buvette) | N300, 2,4 GHz seulement, ~20–40 m. **Mode AP** uniquement, jamais en mode routeur (voir §4). Ce n'est pas un modèle d'extérieur. |

### Ce qu'il faut ajouter pour couvrir tout un village

Un village, c'est souvent 500 m à 2 km de diamètre. Des routeurs d'intérieur ne suffisent pas.
Il faut une **dorsale radio** et des **points d'accès d'extérieur** en hauteur.

| Élément | Exemples | Qté | Prix indicatif |
|---|---|---|---|
| Kit Starlink **Standard** + abonnement | Starlink Standard Kit | 1 | Kit ~200 000–350 000 F, puis abonnement mensuel |
| Onduleur / batterie pour le cœur | Onduleur 1 kVA + batterie, ou kit solaire 300–500 W | 1 | 80 000–250 000 F |
| Switch PoE 8 ports | MikroTik hEX PoE, TP-Link TL-SG1008P | 1 | 30 000–60 000 F |
| **Liaison radio point-multipoint** (base au centre) | MikroTik mANTBox 52 15s, Ubiquiti LiteAP AC | 1 | 70 000–120 000 F |
| **Récepteurs radio** dans chaque quartier | MikroTik SXTsq 5 ac, LHG 5, Ubiquiti LiteBeam 5AC | 1 par quartier | 35 000–60 000 F |
| **Points d'accès extérieurs** pour les téléphones (2,4 GHz) | MikroTik mANTBox 2, cAP ax, TP-Link EAP225/EAP610-Outdoor, Ubiquiti UAP-AC-Mesh | 1 à 3 par quartier | 45 000–110 000 F |
| Mâts / poteaux 6–12 m, boîtiers étanches, câble FTP **extérieur** blindé, connecteurs, parafoudres Ethernet, mise à la terre | — | — | 100 000–300 000 F |

> **Règle de couverture :** un point d'accès extérieur bien placé à 8–10 m de haut couvre un rayon
> d'environ 100–200 m pour un téléphone. Le facteur limitant, c'est le téléphone, qui émet peu.
> Compte **1 point d'accès extérieur pour 150–200 m** de rayon et place-les aux lieux de vie
> (marché, place, école, gare routière, maquis).

### Capacité : combien de clients

* Starlink donne en général 50–200 Mbit/s en descente et 10–30 Mbit/s en montée, selon l'heure et la région.
* Avec 1–4 Mbit/s par client et le partage équitable (PCQ), **80 à 150 clients actifs en même temps** se passent bien.
* Au-delà, ajoute une 2e source (2e Starlink, 4G ou fibre) et un équilibrage de charge. Je peux t'écrire le script.

---

## 2. Démarches avant d'acheter (important)

1. **Disponibilité Starlink** : vérifie ton adresse exacte sur starlink.com.
2. **Formule Starlink** : la formule *Résidentielle* interdit de **revendre** la connexion.
   Pour une Wi-Fi Zone commerciale, prends une **formule professionnelle (Business / Local Priority)**.
   Lis les conditions sur le site.
3. **Autorisation** : revendre de l'accès internet peut demander une déclaration ou une licence
   auprès du régulateur télécom (ARTCI en Côte d'Ivoire, ARCEP au Bénin, AMRTP au Mali…). Renseigne-toi
   avant le lancement commercial.
4. **Moneroo** : crée le compte et lance la **vérification d'identité (KYC) tout de suite**.
   Elle peut prendre plusieurs jours.
5. **Nom de domaine** (ex. `mazone.com`), 8–15 $ par an.

---

## 3. Étape 1 : Starlink

1. Installe l'antenne **en hauteur, avec une vue dégagée du ciel** (aucun arbre ni toit dans le cône).
   Dans l'appli Starlink, utilise **« Vérifier les obstructions »** avant de fixer l'antenne.
2. Active-la avec l'appli Starlink et vérifie qu'internet fonctionne.
3. Passe le routeur Starlink en **mode Bypass** : appli Starlink → Paramètres → Routeur → *Bypass Starlink WiFi*.
   Son Wi-Fi s'éteint et le MikroTik reçoit internet directement.
   * Starlink Gen 3 / Standard : il faut alors brancher le MikroTik sur le port Ethernet du routeur Starlink.
     Si ton routeur n'a pas de port Ethernet, achète l'**adaptateur Ethernet Starlink**.
   * ⚠ Une fois en Bypass, on ne peut revenir en arrière **que par une réinitialisation d'usine** du routeur
     Starlink. L'antenne reste pilotable depuis l'appli.
4. Branche le câble qui sort du Starlink sur **ether1** du MikroTik.

---

## 4. Étape 2 : MikroTik (fichiers dans `mikrotik/`)

1. Télécharge **WinBox 4** sur mikrotik.com/download et branche ton PC sur **ether3**.
2. Dans WinBox, onglet *Neighbors*, clique sur l'adresse **MAC** du routeur, utilisateur `admin`, mot de passe vide
   (ou celui écrit sur l'étiquette).
3. *System → Packages → Check For Updates* : mets RouterOS 7 à jour (dernière version **stable**).
4. Réinitialise à vide : *New Terminal* →
   `/system reset-configuration no-defaults=yes skip-backup=yes`
   puis reconnecte-toi par l'adresse MAC.
5. Ouvre [01-config-hotspot.rsc](mikrotik/01-config-hotspot.rsc) et **modifie les 5 variables en haut** :
   nom du Wi-Fi, mot de passe admin, ton domaine.
6. *Files* → glisse le fichier → *New Terminal* → `/import file-name=01-config-hotspot.rsc`
7. Envoie le dossier `hotspot/` dans *Files* (il remplace le dossier `hotspot` créé par le routeur).
   Ajoute ton logo dans `hotspot/img/logo.png` et **garde le `md5.js` d'origine**.

Ce script configure :
* le bridge **HOTSPOT** (ether2–5 + Wi-Fi), le réseau 10.10.0.0/22 (≈1000 appareils), le DHCP et le DNS ;
* le NAT, un pare-feu qui ferme le routeur côté internet, et la désactivation des services inutiles ;
* l'**anti-partage de connexion** (TTL = 1) ;
* le **hotspot** avec connexion CHAP + PAP + cookie (le client n'a pas à retaper son code chaque jour) ;
* les forfaits **1H / 24H / 7J / 30J** avec un débit maximum par client ;
* le **walled garden**, c'est-à-dire les sites accessibles sans ticket : ton site d'achat et Moneroo
  (sinon le client ne peut pas payer) ;
* le **partage équitable** du débit Starlink entre tous les clients (PCQ) ;
* la surveillance de la connexion Starlink et le nettoyage automatique des tickets épuisés.

> Mesure ton vrai débit Starlink (speedtest), puis ajuste `max-limit=15M/90M` à environ 90 % de ce débit.
> Sinon les files d'attente ne servent à rien.

---

## 5. Étape 3 : les LB-Link BL-WR2000 en point d'accès

Le LB-Link ne doit **rien router** : il diffuse seulement le Wi-Fi. C'est le MikroTik qui distribue
les adresses et affiche le portail.

1. Branche ton PC sur un port LAN du LB-Link, puis ouvre `http://192.168.16.1` ou l'adresse écrite sous l'appareil.
   Remets-le à zéro (bouton reset, 10 s) s'il a déjà servi.
2. **Mode de fonctionnement : « AP » / « Access Point »** (dans *Operation Mode* ou *Mode de fonctionnement*).
   Si ce mode n'existe pas, reste en mode routeur et fais les étapes 3 à 5 : le résultat est le même.
3. **LAN IP** : donne-lui une adresse fixe dans la plage réservée, par exemple `10.10.0.41` (LB-Link : .41 à .49), masque
   `255.255.252.0`, passerelle `10.10.0.1`. Note l'adresse de chaque AP.
4. **Désactive le serveur DHCP** du LB-Link (c'est essentiel).
5. **Wi-Fi** : SSID **identique** au MikroTik (`VILLAGE-WIFI`), **sans mot de passe** (sécurité « None » /
   « Ouvert »), largeur **20 MHz**.
   Pour les canaux, alterne **1, 6, 11** entre AP voisins (jamais deux AP voisins sur le même canal).
6. Change le **mot de passe d'administration** du LB-Link.
7. Branche le câble venant du MikroTik ou du switch sur un **port LAN** (pas WAN) du LB-Link.
8. Test : connecte un téléphone au Wi-Fi du LB-Link → le portail du MikroTik doit s'afficher.

> Ne mets pas le LB-Link en mode « Repeater » ou « WISP » pour étendre la couverture : le débit est
> divisé par deux à chaque saut et c'est instable. Relie toujours un AP par câble ou par une liaison radio dédiée.

---

## 6. Étape 4 : la dorsale radio vers les quartiers

1. Au point central (sur le mât, près du Starlink) : une **base point-multipoint** 5 GHz (mANTBox 52 / LiteAP)
   branchée sur le switch, en **mode AP Bridge**.
2. Dans chaque quartier : un **récepteur** (SXTsq / LHG / LiteBeam) en mode **Station Bridge**
   (ou *station-bridge* chez MikroTik, *Station + WDS* chez Ubiquiti), orienté vers la base.
3. Derrière chaque récepteur : un petit switch PoE ou un injecteur PoE, puis 1 à 3 **AP extérieurs 2,4 GHz**
   (même SSID ouvert, canaux 1/6/11).
4. Tout reste dans **le même réseau (couche 2)** : tous les clients arrivent sur le bridge HOTSPOT du MikroTik
   et voient le même portail.
5. Sécurise la dorsale : WPA2 avec une clé forte sur le **5 GHz** de la dorsale (pas sur le Wi-Fi clients).
6. Mets un **parafoudre** sur chaque câble qui descend d'un mât et **relie chaque mât à la terre**.
   C'est la 1re cause de pannes en saison des pluies.

Je peux te préparer les scripts de configuration exacts de chaque radio quand tu auras choisi les modèles.

---

## 7. Étape 5 : le serveur de paiement (dossier `backend/`)

Une seule application Node.js qui fait **tout** : site d'achat, API, webhook Moneroo et synchro du routeur.
C'est plus simple que la formation : pas de site séparé à héberger sur Vercel.

### 7.1 Base de données (Supabase)
1. Crée un projet sur supabase.com (région Europe).
2. *SQL Editor* → colle tout [schema.sql](backend/schema.sql) → **Run**.
3. *Project Settings → Database → Connection string (URI, Session pooler)* : ce sera ton `DATABASE_URL`.

### 7.2 Moneroo
1. Compte sur moneroo.io, puis KYC.
2. *Developers → API Keys* : copie la **clé secrète de test** dans `MONEROO_SECRET_KEY`.
3. Active les méthodes de ton pays (Orange, MTN, Moov, Wave).

### 7.3 En local (pour tester)
```powershell
cd backend
copy .env.example .env      # puis remplis .env toi-même
npm install
npm run zone:create -- "VILLAGE WI-FI" CI 2250700000000
npm start
```
`zone:create` affiche ton **ZONE_ID** et ton **ROUTER_TOKEN** (garde-le secret).

### 7.4 Mise en ligne (Render, ~7 $/mois)
1. Mets le dossier `backend` sur GitHub (dépôt **privé**). Le `.env` est exclu par `.gitignore`.
2. render.com → *New Web Service* → ton dépôt. Réglages : *Build* `npm install`, *Start* `npm start`,
   plan **Starter** (le plan gratuit s'endort et les clients attendent une minute).
3. *Environment* : recopie les variables de ton `.env` avec `PUBLIC_URL=https://mazone.com`.
4. *Custom Domain* : ajoute `mazone.com` et crée chez ton registraire l'enregistrement DNS indiqué.
5. Moneroo → *Developers → Webhooks* → URL : `https://mazone.com/api/moneroo/webhook`
   (événements `payment.success`, `payment.failed`, `payment.cancelled`).
   Copie le **secret de signature** dans `MONEROO_WEBHOOK_SECRET` sur Render.

> Si tout est sur un seul domaine, mets ce même domaine dans `SITEDOMAIN` **et** `APIDOMAIN` du script MikroTik.

### 7.5 Relier le MikroTik au serveur
1. Dans [02-sync-tickets.rsc](mikrotik/02-sync-tickets.rsc), remplace `api.mazone.com`, `ZONE_ID` et `ROUTER_TOKEN`.
2. Importe-le dans le routeur (comme à l'étape 2).
3. Au bout de 2 minutes : *IP → Hotspot → Users* affiche 60 tickets par forfait avec le commentaire `auto:…`.
   Le stock se recharge tout seul.
4. Dans [login.html](hotspot/login.html), remplace `mazone.com`, `ZONE_ID` et le numéro WhatsApp,
   puis renvoie le fichier dans *Files → hotspot*.

### 7.6 Suivre tes ventes
1. Dans `.env` (et sur Render), choisis un mot de passe long : `ADMIN_PASSWORD=...`.
   Mets aussi `COMMISSION_PERCENT=` avec le taux réel de ton contrat Moneroo.
2. Ouvre **`https://mazone.com/admin.html`** sur ton téléphone ou ton PC et entre ce mot de passe.

Le tableau de bord se met à jour tout seul toutes les 60 s. Il affiche :
* le chiffre d'affaires **du jour, sur 7 jours, sur 30 jours et depuis le début**, en brut et en net (commission déduite) ;
* un **graphique des ventes par jour** (touche une barre pour voir le détail) ;
* la **répartition par forfait et par opérateur** (Orange, MTN, Moov, Wave) ;
* le **stock de tickets** par forfait, avec le **prix modifiable** directement et une case pour **retirer un forfait de la vente** ;
* l'**état du routeur** (en ligne ou hors ligne selon la dernière synchro) ;
* les **alertes** : stock bas, routeur muet depuis plus de 10 min, client payé sans ticket
  (avec un bouton **« Attribuer un ticket »**), paiements bloqués « en attente » (avec un bouton **« Vérifier »**) ;
* les 40 derniers paiements, avec le ticket donné à chacun ;
* un bouton **Export CSV** qui s'ouvre dans Excel pour ta comptabilité.

> Le prix modifié s'applique tout de suite aux nouvelles ventes. Pense à changer aussi le tarif
> affiché dans `login.html` et sur ton affiche.

### 7.7 Tickets papier pour les revendeurs
Pour ceux qui n'ont pas de Mobile Money, ou qui préfèrent payer en espèces chez un commerçant :
1. Tableau de bord → **Tickets papier** → choisis le forfait et la quantité (40 = 1 page A4) → **Créer le lot**.
2. Attends 2 minutes : le routeur récupère les codes à sa synchro, et le lot passe à **« prêt »**.
   Le bouton Imprimer reste bloqué tant que tous les codes ne sont pas sur le routeur, donc tu ne peux pas
   imprimer un ticket qui serait refusé.
3. **🖨 Imprimer**, puis découpe le long des pointillés.
4. Confie les tickets aux revendeurs. Ils **ne sont jamais vendus en ligne** : le stock papier et le stock
   en ligne sont séparés (colonne « Papier » du tableau de bord).

**Conseil revendeur :** vends-lui les tickets avec une remise de 15 à 20 % (par exemple, il achète 40 tickets
24 h à 160 F et les revend 200 F). Fais-le payer à la livraison du lot et note le numéro du lot.

### 7.8 L'affiche
Tableau de bord → **🪧 Créer l'affiche**. Les prix sont repris automatiquement de tes forfaits.
Modifie le nom, le Wi-Fi, le slogan et le WhatsApp, choisis **A4 ou A3**, puis **Imprimer** (ou « Enregistrer en PDF »
pour l'envoyer chez un imprimeur).
L'affiche contient 2 QR codes :
* **QR 1** : le téléphone se connecte au Wi-Fi sans rien taper.
* **QR 2** : la page d'achat s'ouvre directement.

Plastifie-la, ou fais-la imprimer sur bâche si elle doit rester dehors (soleil et pluie).
Places conseillées : à l'entrée du marché, à la boutique de chaque revendeur, à la gare routière et à l'école.

---

## 8. Test complet avant ouverture

- [ ] Téléphone neuf sur le Wi-Fi → le portail s'ouvre tout seul.
- [ ] « Acheter un ticket » → la page d'achat s'ouvre **sans ticket**. Sinon, il manque un domaine
      dans le walled garden : regarde *IP → Hotspot → Host* ou ajoute le domaine bloqué.
- [ ] Paiement test (passerelle démo Moneroo) → le code s'affiche en moins de 10 s.
- [ ] « Me connecter maintenant » → internet fonctionne.
- [ ] « Retrouver mon ticket » avec le numéro et le montant → le code est retrouvé.
- [ ] Partage de connexion depuis le téléphone client → les autres appareils n'ont **pas** internet (TTL).
- [ ] Clé Moneroo de **production** sur Render → un **vrai** achat de 100 F avec ton propre numéro.
- [ ] Coupe le courant du MikroTik → au redémarrage, tout revient sans intervention.
- [ ] Une affiche à l'entrée : nom du Wi-Fi, prix, « Payez par Orange / MTN / Moov / Wave », numéro WhatsApp.

---

## 9. Exploitation et dépannage

| Problème | Cause probable | Solution |
|---|---|---|
| Le client a payé mais ne voit pas de code | Webhook refusé (mauvais secret) | Vérifie `MONEROO_WEBHOOK_SECRET`. La page ticket vérifie aussi directement chez Moneroo au bout de 8 s. |
| « Forfait momentanément épuisé » | Le routeur ne se synchronise plus | Regarde `last_router_sync` dans les stats et le *Log* du MikroTik (`sync-tickets`). |
| La page Moneroo ne s'ouvre pas sur le Wi-Fi | Domaine de paiement bloqué | Ajoute-le au walled garden (les passerelles peuvent changer selon l'opérateur). |
| Le code est refusé | Ticket absent du routeur (routeur réinitialisé) | Ouvre une fois l'URL de synchro avec `&full=1` pour renvoyer tous les tickets libres. |
| Internet lent le soir | Trop de clients pour le débit Starlink | Baisse les `rate-limit`, vérifie la PCQ, ajoute une 2e source. |
| Statut `paid_no_stock` | Paiement reçu sans stock disponible | Rembourse le client ou donne-lui un code à la main (cas rare : le stock se recharge toutes les 2 min). |

**Tous les mois :** sauvegarde le MikroTik (*Files → Backup*), mets RouterOS à jour, vérifie les
parafoudres, nettoie l'antenne Starlink.

**Ventes hors ligne :** tu peux garder Mikhmon (vu dans ta formation) pour imprimer des tickets papier
destinés aux revendeurs. Utilise un **autre préfixe** ou **d'autres profils**, pour ne pas les confondre
avec les tickets en ligne (`comment=auto:…`).

---

## 10. Budget de démarrage (ordre de grandeur, à vérifier localement)

| Poste | Montant |
|---|---|
| Starlink (kit) | 200 000–350 000 F |
| MikroTik hAP ac³ + LB-Link (déjà achetés) | — |
| Dorsale radio (1 base + 3 récepteurs) | 180 000–300 000 F |
| 4–6 AP extérieurs | 200 000–500 000 F |
| Mâts, câbles, parafoudres, switch PoE | 150 000–350 000 F |
| Énergie (onduleur / solaire) | 100 000–400 000 F |
| **Total matériel** | **≈ 0,8 à 1,9 million F CFA** |
| Mensuel : Starlink + Render (~4 500 F) + domaine | selon la formule Starlink |
| Commission Moneroo | quelques % par vente |

**Rentabilité :** à 200 F le ticket 24 h, 50 tickets par jour rapportent 10 000 F par jour, soit environ 300 000 F par mois.
