# Fiche App Store — PausePump

Tout le contenu textuel de la fiche App Store Connect, prêt à copier-coller.
Équivalent iOS de [fiche-play-store.md](fiche-play-store.md).

> **Prérequis bloquant** — App Store Connect refuse la création d'une app tant
> que le **contrat de licence de l'Apple Developer Program mis à jour** n'a pas
> été accepté par le titulaire du compte, sur
> <https://developer.apple.com/account>. C'est un contrat : il doit être signé
> par Steven Dieu, personne d'autre.

## Informations générales

| Champ | Valeur |
|---|---|
| Nom (max 30) | `PausePump` (9) |
| Bundle ID | `com.ligolabs.pausepump` |
| SKU | `pausepump-ios-001` |
| Langue principale | Français (France) |
| Prix | Gratuit, aucun achat intégré |
| Cible | iPhone **et** iPad (`TARGETED_DEVICE_FAMILY = 1,2`), iOS 13.0 minimum |

L'app embarque aussi une **app Apple Watch**
(`com.ligolabs.pausepump.watchkitapp`) et une **extension Live Activity**
(`com.ligolabs.pausepump.widgets`). Ces bundle IDs doivent exister dans le
portail développeur avant l'archive.

## Sous-titre (max 30)

```
Minuteur de repos muscu
```
23 caractères. Alternatives : `Chrono de repos à la salle` (26) ·
`Tes temps de repos, réglés` (26)

## Texte promotionnel (max 170)

Modifiable sans repasser en revue — pratique pour annoncer une nouveauté.

```
Lance ta pause, pose ton téléphone, soulève. Le bip de fin sonne même écran verrouillé, et dans tes écouteurs s'ils sont branchés.
```
128 caractères.

## Description (max 4000)

```
PausePump chronomètre tes temps de repos à la salle. Pas de compte, pas de pub, pas de connexion : tu ouvres, tu lances, tu soulèves.

DEUX MODES
• Pause seule : tu fais ta série, tu valides, la pause démarre.
• Effort + Pause : l'effort ET la pause sont chronométrés, en enchaînement automatique ou étape par étape.

PENSÉ POUR LES MAINS CHARGÉES
Un double tap n'importe où sur l'écran enchaîne : valide ta série ou relance la dernière durée utilisée. Pas besoin de viser un bouton entre deux séries. Avec un clavier ou une télécommande Bluetooth, la touche Espace fait la même chose.

LE BIP SONNE VRAIMENT
Le décompte continue quand tu quittes l'app, avec le temps restant affiché sur l'écran verrouillé et dans la Dynamic Island. Le signal de fin sort dans tes écouteurs s'ils sont branchés.

SUR TON POIGNET
L'app Apple Watch reprend le minuteur en entier : lance ta pause et valide tes séries sans sortir ton téléphone de ta poche.

RÉGLABLE
• Durées préréglées et personnalisables
• 5 sons de bip au choix, volume réglable, vibration
• Décompte de préparation « 3, 2, 1, GO » avant l'effort
• Écran maintenu allumé pendant le décompte
• Compteur de séries avec barre de progression

AUCUNE DONNÉE COLLECTÉE
Tout reste sur ton appareil. Pas de compte, pas de tracker, pas de publicité. Fonctionne à 100 % hors ligne.

Existe aussi en version web.
```

## Mots-clés (max 100 caractères, séparés par des virgules)

```
repos,muscu,série,chrono,minuteur,fitness,entrainement,salle,gym,timer,pause,hiit,tabata,sport
```
94 caractères. Ne pas répéter les mots déjà présents dans le nom et le
sous-titre : Apple les indexe de toute façon.

## URL

| Champ | Valeur |
|---|---|
| URL d'assistance (obligatoire) | `https://github.com/LigoLabs/PausePump/issues` |
| URL marketing (facultative) | `https://ligolabs.github.io/PausePump/` |
| URL de politique de confidentialité | `https://ligolabs.github.io/PausePump/privacy.html` |

## Catégories

- Principale : **Forme et santé**
- Secondaire : **Sports** (facultatif)

## Classification par âge

Toutes les questions du questionnaire → **Aucun / Jamais**. L'app ne contient
ni violence, ni contenu sexuel, ni jeu d'argent, ni alcool/tabac/drogue, ni
contenu généré par les utilisateurs, ni navigateur web illimité. Résultat
attendu : **4+**.

Nouveauté 2025 : Apple pose des questions sur les **capacités de réseaux
social**. Réponse pour PausePump : aucune — pas de messagerie, pas de profil,
pas de partage entre utilisateurs.

## Confidentialité de l'app (étiquette « nutrition »)

**« Les données ne sont pas collectées »** — c'est la seule réponse à donner.
PausePump ne transmet rien hors de l'appareil : les réglages et la séance en
cours vivent dans le stockage local (UserDefaults), l'app fonctionne hors
ligne et n'embarque aucun SDK d'analyse ou de publicité.

## Conformité à l'exportation

`ITSAppUsesNonExemptEncryption = false` est déjà dans `Runner/Info.plist` :
la question ne sera donc pas reposée à chaque envoi de build.

## Notes pour l'examen (App Review)

```
PausePump est un minuteur de temps de repos pour la musculation. Aucun compte n'est nécessaire : toutes les fonctionnalités sont accessibles dès l'ouverture, sans connexion ni achat.

Pour tester : choisir un nombre de séries sur l'écran d'accueil, appuyer sur « C'est parti », valider une série, puis choisir une durée de pause. Le décompte démarre.

Quand l'utilisateur quitte l'app ou verrouille son téléphone pendant une pause, le signal de fin est émis par une notification locale programmée à l'avance, et le temps restant s'affiche sur l'écran verrouillé et dans la Dynamic Island via une Live Activity. L'app ne déclare aucun mode d'exécution en arrière-plan.
```

## Captures d'écran

**À produire depuis le simulateur iOS au moment du build** — les captures
Android du dossier `screenshots/` ne conviennent pas : elles n'ont pas les
dimensions exigées par Apple, et une fiche App Store doit montrer l'app telle
qu'elle tourne sur iOS.

Tailles réellement demandées par la fiche (relevées dans App Store Connect,
elles diffèrent de ce que documente Apple ailleurs) :

| Appareil | Dimensions acceptées |
|---|---|
| iPhone écran 6,5″ | 1242 × 2688, 2688 × 1242, 1284 × 2778 ou 2778 × 1284 |
| iPad | onglet dédié dans le gestionnaire des visuels |
| Apple Watch | onglet dédié |

Seules les **3 premières captures** sont utilisées sur les fiches
d'installation ; jusqu'à 10 par taille. Les captures fournies pour l'iPhone
servent à toutes les langues et toutes les tailles d'écran si aucune variante
n'est ajoutée.

Mêmes écrans que sur Play, dans cet ordre : accueil, « Fais ta série », choix
de durée, minuteur en cours, options.

## Points de vigilance pour la revue

**`UIBackgroundModes = audio` a été retiré** (le 31 juillet 2026, avant la
première soumission). Ce mode vise les apps qui diffusent de l'audio en
continu ; l'App Review le rejette au titre du point 2.5.4 quand rien n'est
joué en arrière-plan — et c'était précisément le cas ici : le seul chemin de
bip en arrière-plan est conditionné à `Platform.isAndroid`
(`lib/state/timer_controller.dart`), donc sur iOS le mode ne servait à rien.

Le comportement iOS est inchangé sans lui : le signal de fin vient de la
notification locale programmée (`NotificationService.scheduleEnd`) et le
décompte écran verrouillé de la Live Activity. Le bip de premier plan reste
audible cloche coupée grâce à la catégorie AVAudioSession `.playback`, qui
ne dépend pas de ce mode.

**Ne pas le réintroduire** sans ajouter en même temps une vraie lecture audio
continue en arrière-plan.

**Entitlement « Time Sensitive Notifications »** — à activer sur les App IDs
`com.ligolabs.pausepump` et `.watchkitapp` dans le portail développeur, sinon
la signature échoue à l'archive (voir `ios/scripts/setup_ios_targets.rb`).

**Icône de l'app Watch** — générée par `node scripts/gen_icons.js`, déjà en
place dans `ios/PausePumpWatch/Assets.xcassets`. Une app watchOS sans icône
propre est refusée.
