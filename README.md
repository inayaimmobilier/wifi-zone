# Wi-Fi Zone Village

Vente automatique de tickets Wi-Fi MikroTik payés en Mobile Money (Moneroo), pour un village couvert par Starlink.

| Dossier | Contenu |
|---|---|
| `backend/` | Serveur Node.js : page d'achat, webhook Moneroo, synchro routeur, tableau de bord `/admin.html`, affiche, tickets papier |
| `mikrotik/` | Scripts RouterOS : routeur hotspot, synchro des tickets, radios base/station, points d'accès |
| `hotspot/` | Pages du portail captif à envoyer dans le MikroTik |
| `GUIDE-PROJET.md` | Le guide complet de A à Z |
| `PLAN-VILLAGE-CI.md` | Plan réseau et matériel du village |

## Lancer en local
```powershell
cd backend
copy .env.example .env   # puis remplis .env
npm install
npm start
```

## Mise en ligne
Render → **New → Blueprint** → ce dépôt (`render.yaml`). Voir `GUIDE-PROJET.md` §7.
