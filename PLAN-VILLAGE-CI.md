# Plan réseau : village en Côte d'Ivoire (1–2 km, 4 à 6 quartiers, courant stable)

## 1. Schéma

```
                         [Starlink] (sur le mât central, ciel dégagé)
                              │
   SITE CENTRAL  ──  mât 12–15 m, le point le plus haut et le plus central possible
   ┌──────────────────────────────────────────────────────────────┐
   │ Routeur Starlink (bypass) ─► hAP ac³ (hotspot) ─► switch PoE │
   │                                   │                          │
   │              ┌────────────────────┼───────────────┐          │
   │      Radio BASE 5 GHz      AP 2,4 GHz du centre   LB-Link     │
   │   (OmniTIK 5 ac ou          (mANTBox 2 12s)     (boutique)    │
   │    mANTBox 52 15s)                                            │
   └──────────────┬───────────────────────────────────────────────┘
                  │  dorsale 5 GHz chiffrée (nv2), ≤ 1 km par lien
     ┌────────────┼────────────┬────────────┬────────────┐
   Quartier 1   Quartier 2   Quartier 3   Quartier 4   Quartier 5 (et 6)
   (marché)     (école)      (gare)       (mosquée/    (…)
                                           église)
   Dans chaque quartier, mât de 6–9 m sur une maison :
     SXTsq 5 ac (station) ─► hEX PoE lite ─► 1–2 mANTBox 2 12s (Wi-Fi clients)
                                         └─► LB-Link en intérieur (facultatif)
```

**Pourquoi ce choix pour ton village :**
* 1 à 2 km de bout en bout, donc **au plus ~1 km** du centre jusqu'au quartier le plus éloigné.
  Un SXTsq 5 ac (16 dBi) reçoit très bien une base à cette distance, avec 100 à 200 Mbit/s par lien,
  plus que le débit de Starlink.
* Le courant est stable : pas de solaire, juste un petit **onduleur** au site central et une
  **multiprise parafoudre** par quartier.
* Tout est en MikroTik : un seul logiciel (WinBox), des scripts prêts à coller, et le protocole
  **nv2** qui tient beaucoup mieux la charge en point-multipoint que le Wi-Fi classique.

### Choisir la base selon l'emplacement du site central
| Site central… | Radio base | Pourquoi |
|---|---|---|
| **au milieu** du village (quartiers tout autour) | **OmniTIK 5 ac** (omnidirectionnelle 360°) | Elle atteint tous les quartiers dans un rayon d'environ 1 km. |
| **en bordure** (quartiers tous du même côté) | **mANTBox 52 15s** (secteur 90–120°) | Elle porte plus loin et capte moins de parasites. Oriente-la vers le centre du village. |
| quartiers dans 2 directions opposées | 2 × mANTBox 52 15s, sur 2 canaux différents | Chaque secteur couvre un côté du village. |

## 2. Liste de matériel (5 quartiers + centre)

Les prix sont des ordres de grandeur en F CFA à Abidjan (Adjamé / revendeurs MikroTik).
Demande 2 ou 3 devis.

| # | Élément | Qté | Prix unitaire | Total |
|---|---|---|---|---|
| **Site central** |||||
| 1 | Kit Starlink Standard + support de fixation | 1 | à vérifier sur starlink.com | — |
| 2 | MikroTik hAP ac³ | 1 | déjà acheté | — |
| 3 | OmniTIK 5 ac **ou** mANTBox 52 15s | 1 | 90 000–140 000 | ~120 000 |
| 4 | mANTBox 2 12s (Wi-Fi clients du centre) | 1 | 70 000–90 000 | 80 000 |
| 5 | Switch PoE (MikroTik hEX PoE ou netPower) | 1 | 45 000–70 000 | 55 000 |
| 6 | Mât galvanisé 12–15 m + haubans | 1 | 80 000–150 000 | 110 000 |
| 7 | Onduleur 1 kVA (autonomie 30–60 min) | 1 | 60 000–100 000 | 80 000 |
| **Par quartier (×5)** |||||
| 8 | SXTsq 5 ac (station dorsale) | 5 | 40 000–55 000 | 240 000 |
| 9 | mANTBox 2 12s (Wi-Fi clients) | 5 | 70 000–90 000 | 400 000 |
| 10 | hEX PoE lite (alimente station + AP) | 5 | 35 000–50 000 | 210 000 |
| 11 | Tube / mât 6–9 m + fixations | 5 | 25 000–50 000 | 190 000 |
| 12 | Boîtier étanche + multiprise parafoudre | 5 | 10 000–20 000 | 75 000 |
| **Commun** |||||
| 13 | Câble FTP Cat6 **extérieur** blindé (305 m) | 1 | 60 000–90 000 | 75 000 |
| 14 | Parafoudres Ethernet PoE (1 par câble descendant d'un mât) | 12 | 8 000–15 000 | 130 000 |
| 15 | Connecteurs blindés, pince à sertir, colliers UV, piquets de terre | — | — | 60 000 |
| 16 | Pose (électricien, montage des mâts) | — | — | 100 000–200 000 |
| | **Total hors Starlink** | | | **≈ 1,9 à 2,1 millions F CFA** |

Pour démarrer moins cher : commence avec le centre et **2 quartiers** (≈ 1 million F).
Ajoute ensuite les autres quartiers avec les recettes : chaque quartier ajouté coûte ≈ 220 000 F.

## 3. Plan d'adresses (déjà prévu dans les scripts)

| Adresse | Équipement |
|---|---|
| 10.10.0.1 | hAP ac³ (passerelle, hotspot) |
| 10.10.0.2 | Radio base |
| 10.10.0.11 → .16 | Stations SXTsq (Q1 → Q6) |
| 10.10.0.21 → .36 | AP extérieurs mANTBox 2 |
| 10.10.0.41 → .49 | LB-Link en mode AP |
| 10.10.0.50 → 10.10.3.250 | Téléphones des clients (DHCP) |

Les équipements .2 à .49 sont exemptés du portail (`ip-binding bypassed`) : ils peuvent donner l'heure
et se mettre à jour sans ticket.

## 4. Plan des fréquences

* **Dorsale 5 GHz** : un seul canal pour la base, par exemple 5180 MHz en 40 MHz. Avant de le choisir,
  lance *Wireless → Frequency Usage* sur la base pour trouver le canal le plus libre.
  Le Wi-Fi 5 GHz du hAP ac³ doit être sur un **autre** canal (ou désactivé s'il est sur le même mât).
* **Wi-Fi clients 2,4 GHz** : 3 canaux seulement, **1 / 6 / 11** (2412 / 2437 / 2462 MHz), toujours en **20 MHz**.

| Point d'accès | Canal |
|---|---|
| Centre (mANTBox) | 1 |
| hAP ac³ | 6 |
| Q1 | 11 |
| Q2 | 1 |
| Q3 | 6 |
| Q4 | 11 |
| Q5 | 1 (loin du centre) |
| LB-Link | le canal libre le plus éloigné de l'AP voisin |

## 5. Ordre d'installation (prévoir 3–5 jours)

1. **Jour 1, au sol, sur une table** : configure tout le matériel avant de monter sur les mâts.
   * hAP ac³ : `01-config-hotspot.rsc` puis `02-sync-tickets.rsc`
   * Base : `03-radio-base.rsc`
   * Chaque station : `04-radio-station.rsc` (change NOM et IP)
   * Chaque AP : `05-ap-exterieur.rsc` (change NOM, IP et FREQ)
   * Colle une étiquette sur chaque appareil (nom + IP).
   * Teste sur la table : station connectée à la base → un téléphone sur l'AP voit le portail → achat test.
2. **Jour 2, site central** : mât, Starlink, routeur, base, onduleur, mise à la terre.
3. **Jours 3–4, quartiers** : choisis une maison qui **voit le mât central** (pas de gros manguier ou fromager
   entre les deux, car les feuilles bloquent le 5 GHz). Monte le mât à 6–9 m et oriente le SXTsq vers la base.
   Vise un signal **entre −55 et −68 dBm** (*Wireless → Registration*), puis fixe l'AP vers les habitations.
4. **Jour 5** : tour du village avec un téléphone. Note les zones sans réseau et ajuste l'orientation des AP.

**Accord avec les familles qui hébergent un quartier** : un forfait 30 jours gratuit par mois, ou une petite
somme, en échange du courant (≈ 20 W par quartier, quelques centaines de F par mois) et de l'accès au toit.
Mets-le par écrit.

## 6. Côte d'Ivoire : points spécifiques

* **Paiement** : CinetPay (société ivoirienne) accepte Orange Money, MTN, Moov et Wave CI.
  Teste **chaque** opérateur avec un vrai achat de 100 F avant l'ouverture.
* **Wave** ouvre parfois son application ou une page `wave.com` : si le paiement Wave bloque sur le Wi-Fi,
  ajoute au walled garden le domaine qui apparaît dans *IP → Hotspot → Host*.
* **Numéros** : 10 chiffres (07…, 05…, 01…). Le serveur ajoute 225 et garde le 0 (`2250707123456`).
* **Réglementation** : la revente d'accès internet relève de l'**ARTCI**. Renseigne-toi sur le régime
  applicable (déclaration ou autorisation) avant le lancement commercial, et garde une trace écrite.
* **Starlink** : vérifie sur starlink.com que le service est disponible à l'adresse du village.
  Prends une formule qui autorise l'usage commercial.

## 7. Tarifs conseillés pour un village

| Forfait | Prix | Profil MikroTik | Débit max |
|---|---|---|---|
| 1 heure | 100 F | 1H | 3 Mbit/s |
| 24 heures | 200 F | 24H | 4 Mbit/s |
| 7 jours | 1 000 F | 7J | 5 Mbit/s |
| 30 jours | 3 000 F | 30J | 6 Mbit/s, 2 appareils |

Pour les modifier : change la liste `FORFAITS` dans `backend/scripts/create-zone.js` **et** les profils dans
`01-config-hotspot.rsc`. Le nom du profil doit être **identique** des deux côtés.
