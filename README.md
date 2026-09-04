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

## Changer les horaires des cours

Les créneaux sont définis une seule fois, dans le tableau `SLOTS` en tête du
script de `index.html` :

```js
const SLOTS = [
  { debut: "8h00",  fin: "9h00"  },
  ...
  { debut: "12h00", fin: "12h45", pause: true },
  { debut: "13h30", fin: "14h30" },
];
```

`pause: true` marque les créneaux de la pause méridienne. Ajouter ou retirer une
ligne décale les cours existants : dans ce cas, vérifier l'emploi du temps après
coup et corriger les cours déplacés depuis le mode Modifier.

## Apparence

L'icône palette dans l'en-tête ouvre un réglage à deux axes, mémorisé par
appareil : le **thème** (Automatique / Clair / Sombre) et le **style des cours**
(Pastel ou Couleurs vives). En style vif, la clarté de chaque couleur est
calculée au chargement pour garantir un contraste d'au moins 4,6:1 avec le texte
blanc — c'est pourquoi un jaune sort plus foncé qu'un bleu.

## Le code de modification

Le code ne se trouve **nulle part dans ces fichiers** : il vit uniquement dans
la base, sous forme d'empreinte SHA-256, et c'est Supabase qui le vérifie.

La page ne peut plus écrire directement dans la table : elle appelle la fonction
`edt_enregistrer(id, code, cours)`, qui refuse tout enregistrement sans le bon
code. La clé publique seule ne permet donc que la lecture. Après 10 essais
ratés, la vérification est bloquée 15 minutes.

Pour changer le code : rejouer `supabase.sql` dans l'éditeur SQL de Supabase en
remplaçant `ICI_LE_CODE` par le nouveau code **au moment de coller**, sans
réenregistrer le fichier. Rien à modifier dans `index.html`, rien à pousser.

## Notes

- Sans configuration Supabase, la page fonctionne quand même : les modifications
  restent dans le navigateur de l'appareil (localStorage).
- Le service worker est en **Network First** : ne pas le repasser en Cache First,
  sinon une page mise à jour peut s'afficher sans son style.
- Après chaque modification de `index.html`, incrémenter `CACHE` dans `sw.js`
  (`edt-soleane-v1` → `v2`, etc.) pour forcer le rafraîchissement.
