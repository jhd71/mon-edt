# Emploi du temps de Soleane

Page web (PWA) affichant l'emploi du temps de la classe 4G3, consultable sur PC et
mobile, modifiable à tout moment et synchronisée entre les appareils via Supabase.

## Fichiers

| Fichier | Rôle |
|---|---|
| `index.html` | toute l'application (HTML + CSS + JS) |
| `manifest.json` | permet l'ajout à l'écran d'accueil |
| `sw.js` | service worker — consultation hors ligne |
| `icon-192.png`, `icon-512.png`, `icon-512-maskable.png` | icônes de l'application |
| `supabase.sql` | script à exécuter une fois dans Supabase |

## Installation

1. Exécuter `supabase.sql` dans Supabase (SQL Editor → New query → Run).
2. Dans `index.html`, remplir le bloc `CONFIG` en haut du script :
   `SUPABASE_URL`, `SUPABASE_ANON_KEY` et `CODE_MODIF`.
3. Pousser le dépôt, puis activer GitHub Pages (Settings → Pages → branche `main`, dossier `/root`).

La première ouverture crée automatiquement la ligne dans Supabase avec
l'emploi du temps d'origine.

## Notes

- Sans configuration Supabase, la page fonctionne quand même : les modifications
  restent dans le navigateur de l'appareil (localStorage).
- Le service worker est en **Network First** : ne pas le repasser en Cache First,
  sinon une page mise à jour peut s'afficher sans son style.
- Après chaque modification de `index.html`, incrémenter `CACHE` dans `sw.js`
  (`edt-soleane-v1` → `v2`, etc.) pour forcer le rafraîchissement.
