# Fiche Play Store — PausePump

Textes prêts à copier-coller dans Play Console.

## Fichiers à glisser dans la fiche (dans cet ordre)

| Champ Play Console | Fichier |
|---|---|
| Icône de l'application | `store/play-icon-512.png` (512×512) |
| Image de présentation | `store/feature-graphic-1024x500.png` (1024×500) |
| Captures d'écran pour téléphone | les 5 fichiers de `store/screenshots/` |
| Captures pour tablette 7 pouces | les 4 fichiers de `store/screenshots-tablet7/` |
| Captures pour tablette 10 pouces | les 4 fichiers de `store/screenshots-tablet10/` |

Toutes les captures sont au **ratio 9:16 exact**, le seul accepté par Play
avec le 16:9 (une capture brute de Pixel, en 1080×2400, serait refusée) :

- téléphone et tablette 7″ : 1269×2256
- tablette 10″ : 1692×3008 (Play impose un côté minimum de 1080 px sur ce format)

Les captures tablette ont été prises en faisant rendre un appareil en
tablette via `adb shell wm size` / `wm density` (617 dp de large pour le 7″,
960 dp pour le 10″), sans émulateur de tablette dédié. Retraitement :
`node scripts/crop_screenshots.js [--out=<dossier>] <captures brutes...>`.

## Nom de l'application (max 30)
```
PausePump
```

## Description courte (max 80) — 74 caractères
```
Minuteur de repos pour la muscu. Double tap pour enchaîner tes séries.
```

## Description longue (max 4000)
```
PausePump chronomètre tes temps de repos à la salle. Pas de compte, pas de pub,
pas de connexion : tu ouvres, tu lances, tu soulèves.

⏱️ DEUX MODES
- Pause seule : tu fais ta série, tu valides, la pause démarre.
- Effort + Pause : l'effort ET la pause sont chronométrés, en enchaînement
  automatique ou étape par étape.

👆 PENSÉ POUR LES MAINS CHARGÉES
Un double tap n'importe où sur l'écran enchaîne : valide ta série ou relance
la dernière durée utilisée. Pas besoin de viser un bouton entre deux séries.
Sur clavier ou télécommande Bluetooth, la touche Espace fait la même chose.

🔔 LE BIP SONNE VRAIMENT
Le décompte continue quand tu quittes l'app ou verrouilles ton téléphone, avec
un chrono affiché dans la notification. Le signal de fin sonne même écran
éteint — et sort dans tes écouteurs s'ils sont branchés.

⚙️ RÉGLABLE
- Durées préréglées et personnalisables
- 5 sons de bip au choix, volume réglable, vibration
- Décompte de préparation « 3, 2, 1, GO » avant l'effort
- Écran maintenu allumé pendant le décompte
- Compteur de séries avec barre de progression

🔒 AUCUNE DONNÉE COLLECTÉE
Tout reste sur ton téléphone. Pas de compte, pas de tracker, pas de publicité.
Fonctionne à 100 % hors ligne.

Existe aussi en version web et sur Apple Watch.
```

## Catégorie
Dans l'interface française de Play Console, l'intitulé exact est
**« Santé et bien-être »** (Health & Fitness). Application, pas jeu.
Tags : entraînement, musculation, minuteur, fitness

## Notes de version 1.0.0 (max 500)
```
Première version 🎉
- Minuteur de repos et d'effort, deux modes au choix
- Double tap pour enchaîner tes séries sans viser un bouton
- Le bip de fin sonne écran verrouillé et dans les écouteurs
- 5 sons, vibration, décompte de préparation
- Aucune donnée collectée, fonctionne hors ligne
```

## Sécurité des données — réponses
- Collecte de données : **Aucune**
- Partage de données : **Aucun**
- Données chiffrées en transit : sans objet (aucune donnée transmise)
- Suppression des données : sans objet (désinstaller suffit)
- Le questionnaire se réduit à « Votre appli collecte-t-elle ou partage-t-elle
  les types de données utilisateur requis ? » → **Non**

## Classification du contenu — réponses (déjà saisies)
Catégorie « Tous les autres types d'applications ». Toutes les questions →
**Non**. Résultat : **Toutes les tranches d'âge**.

## Cible et contenu
- Tranches d'âge : **18 ans et plus** (évite les obligations « Familles » ;
  l'app n'est pas destinée aux enfants)
- L'appli attire-t-elle les enfants ? **Non**

## Autres déclarations
- Annonces : **Non** (déjà saisi)
- Informations de connexion : **Non**, rien n'est restreint (déjà saisi)
- Applis gouvernementales : **Non**
- Fonctionnalités financières : **Aucune**
- Santé : **Non** (pas une appli médicale, pas de recherche santé)
- Identifiant publicitaire : **Non**, l'appli n'utilise pas d'ID publicitaire

## App Store (iOS)
- Sous-titre (max 30) : `Minuteur de repos muscu` (23)
- Mots-clés (max 100) :
```
repos,muscu,série,chrono,minuteur,fitness,entrainement,salle,gym,timer,pause
```
