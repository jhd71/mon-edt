# Emploi du temps

Page web (PWA) affichant un emploi du temps de collège, consultable sur PC et
mobile, modifiable à tout moment et synchronisée entre les appareils via Supabase.
Le contenu (cours, devoirs, en-tête) n'est **pas** dans ce dépôt : il est dans
Supabase et ne s'affiche qu'avec le code d'accès.

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

## Les deux codes

Aucun code ne se trouve dans ces fichiers : ils vivent uniquement dans la base,
sous forme d'empreinte SHA-256, et c'est Supabase qui les vérifie.

- **Code d'accès** : demandé une fois par appareil pour **afficher** l'emploi du
  temps (fonction `edt_lire`). Sans lui, Supabase ne renvoie rien.
- **Code de modification** : demandé pour modifier (fonction `edt_sauver`). Il
  marche aussi comme code d'accès.

La table n'est lisible ni modifiable directement avec la clé publique. Après 10
essais ratés, toute vérification est bloquée 15 minutes.

Pour changer un code : voir le §3 de `supabase.sql` (à taper directement dans
l'éditeur SQL de Supabase, sans jamais l'enregistrer dans le dépôt).

## Notes

- Sans configuration Supabase, la page fonctionne quand même : les modifications
  restent dans le navigateur de l'appareil (localStorage).
- Le service worker est en **Network First** : ne pas le repasser en Cache First,
  sinon une page mise à jour peut s'afficher sans son style.
- Après chaque modification de `index.html`, incrémenter `CACHE` dans `sw.js`
  (`edt-soleane-v1` → `v2`, etc.) pour forcer le rafraîchissement.
