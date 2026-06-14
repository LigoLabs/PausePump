# PausePump 💪

Une PWA ultra-simple pour gérer les **temps de repos entre les séries de muscu**.
On ne chronomètre pas l'effort, uniquement les pauses.

👉 **App en ligne :** https://ligolabs.github.io/PausePump/

## Fonctionnalités

- **Accueil** — choisis ton nombre de séries (1 à 6).
- **Pauses** — 7 durées au choix : `30s · 45s · 1:00 · 1:30 · 2:00 · 2:30 · 3:00`.
- **Décompte** — anneau circulaire qui se vide, temps au centre, passage au **rouge** dans les 5 dernières secondes.
- **Contrôles** — ⏸ Pause / ▶ Reprendre · ↺ Reset · ⟲ changer la durée.
- **Compteur de séries** ajustable à la main (− / +) et qui diminue à chaque pause terminée.
- **Fin de séance** — écran « Terminé ! 🎉 » + bouton « Nouvelle séance ».

### Confort mobile

| Fonction | Détail |
| --- | --- |
| 📱 Mobile-first | Gros boutons tactiles |
| 📲 Installable | « Ajouter à l'écran d'accueil » → plein écran |
| 📶 Hors-ligne | Fonctionne sans réseau (service worker) |
| 🔆 Écran allumé | Wake Lock pendant un décompte |
| 🔊 Bip auto | 3 bips générés via Web Audio (sans fichier) |
| 📳 Vibration | Vibre à la fin de la pause |
| 🌙 Thème sombre | Agréable en salle, économe en batterie |

## Stack

100 % statique : HTML / CSS / JavaScript vanilla. Aucune dépendance, aucun build.

```
index.html        # structure des 3 écrans
css/styles.css    # thème sombre, mobile-first
js/app.js         # logique (timer, séries, son, vibration, wake lock)
manifest.json     # PWA installable
sw.js             # cache hors-ligne
icons/            # icônes générées
```

## Lancer en local

N'importe quel serveur statique fait l'affaire :

```bash
python3 -m http.server 8000
# puis ouvrir http://localhost:8000
```

## Déploiement

Le déploiement sur **GitHub Pages** est automatique via GitHub Actions
(`.github/workflows/deploy.yml`) à chaque push.
