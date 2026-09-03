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
   `SUPABASE_URL` et `SUPABASE_ANON_KEY`.
3. Pousser le dépôt, puis activer GitHub Pages (Settings → Pages → branche `main`, dossier `/root`).

La première ouverture crée automatiquement la ligne dans Supabase avec
l'emploi du temps d'origine.

## Changer le code de modification

`CODE_HASH` ne contient pas le code, seulement son empreinte SHA-256 : le code
n'apparaît donc nulle part dans la page, même en lisant le code source.

Pour le changer, ouvrir n'importe quelle page en https, appuyer sur **F12**,
onglet **Console**, coller ceci en remplaçant `2525` par le nouveau code :

```js
crypto.subtle.digest("SHA-256", new TextEncoder().encode("2525"))
  .then(b => console.log([...new Uint8Array(b)].map(o => o.toString(16).padStart(2,"0")).join("")));
```

Copier la longue suite de caractères affichée et la coller à la place de la
valeur de `CODE_HASH` dans `index.html`. Puis incrémenter `CACHE` dans `sw.js`.

## Notes

- Sans configuration Supabase, la page fonctionne quand même : les modifications
  restent dans le navigateur de l'appareil (localStorage).
- Le service worker est en **Network First** : ne pas le repasser en Cache First,
  sinon une page mise à jour peut s'afficher sans son style.
- Après chaque modification de `index.html`, incrémenter `CACHE` dans `sw.js`
  (`edt-soleane-v1` → `v2`, etc.) pour forcer le rafraîchissement.
