# Publier PausePump sur les stores

État : tout ce qui est **automatisable depuis le repo est fait** (icônes,
signature Android, builds). Ce guide liste ce qui est prêt et les étapes
restantes — celles-là exigent tes comptes développeur, personne d'autre ne
peut les faire.

## Ce qui est déjà prêt ✔

- **Icônes natives** : générées par `node scripts/gen_icons.js` (zéro dépendance,
  même design que la PWA) —
  - Android : `mipmap-*/ic_launcher.png` (legacy) + icône **adaptive**
    (fond `values/colors.xml`, motif `ic_launcher_foreground`, variante
    **monochrome** pour les icônes thématiques d'Android 13+) ;
  - iOS : `AppIcon.appiconset` complet, PNG **opaques** (Apple refuse l'alpha) ;
  - Store : `store/play-icon-512.png` (fiche Play) et
    `store/feature-graphic-1024x500.png` (bannière Play).
- **Signature Android** : clé d'upload `android/upload-keystore.jks` +
  `android/key.properties` (tous deux **gitignorés**). `build.gradle.kts` signe
  la release avec, et retombe sur la clé debug si absents (CI).
- **R8/ProGuard** : `android/app/proguard-rules.pro` (obligatoire, sinon crash
  release — voir le commentaire du fichier).
- **Builds** : `flutter build appbundle --release` (Play) et
  `flutter build apk --release` (installation directe).

## ⚠️ À sauvegarder tout de suite (irremplaçable)

Copie ces 2 fichiers dans un gestionnaire de mots de passe / coffre :

- `mobile/android/upload-keystore.jks`
- `mobile/android/key.properties` (contient les mots de passe du keystore)

Ils ne sont **pas dans git** (c'est voulu). Perdus = procédure de
réinitialisation de clé auprès de Google (lente). Divulgués = quelqu'un peut
pousser des mises à jour à ta place.

## Google Play — étapes restantes (~1 h + review)

1. **Compte** : [Play Console](https://play.google.com/console) — 25 $ une fois.
2. **Créer l'app** → nom `PausePump`, français, app, gratuite.
3. **Play App Signing** : accepte (Google garde la clé d'app, ton
   `upload-keystore.jks` sert de clé d'upload).
4. **Uploader** `build/app/outputs/bundle/release/app-release.aab` dans
   *Production → Créer une release* (ou *Tests internes* d'abord, recommandé).
5. **Fiche du store** :
   - icône 512 : `store/play-icon-512.png`
   - bannière : `store/feature-graphic-1024x500.png`
   - 2+ captures d'écran téléphone (prends-les dans l'app : accueil, timer,
     « Fais ta série », réglages)
   - description courte (80 c.) et longue.
6. **Questionnaires obligatoires** : classification du contenu, public cible
   (18+ conseillé vu l'absence de contrôle parental), sécurité des données
   (PausePump ne collecte **rien** : tout est en local — déclare « aucune
   donnée collectée »), et une **politique de confidentialité** (URL requise :
   une page GitHub Pages suffit, dis-le si tu veux que je la génère).
7. Soumettre. Première review : quelques jours.

## App Store (iOS) — étapes restantes

1. **Compte** : [Apple Developer Program](https://developer.apple.com) —
   99 $/an. (Bloquant : sans lui, rien n'est possible côté iOS.)
2. **Identifiants** : dans App Store Connect, crée l'app avec le bundle id du
   Runner (+ ceux de la watch app / Live Activity générés par
   `ios/scripts/setup_ios_targets.rb` s'ils sont soumis ensemble).
3. **Build** : nécessite un Mac (ou la CI macOS du repo) :
   `flutter build ipa --release` puis upload via Transporter ou Xcode.
   La signature (certificats + profils) se configure dans Xcode avec ton
   compte — automatique en général.
4. **Fiche** : captures d'écran (6.7″ et 6.1″ minimum), description,
   politique de confidentialité (même URL que Play), catégorie
   « Forme et santé ».
5. **Export compliance** : l'app n'utilise que HTTPS standard → réponse
   « exempt » (clé `ITSAppUsesNonExemptEncryption=false` déjà posée si
   présente dans l'Info.plist, sinon réponds « non » dans App Store Connect).
6. Soumettre. Review : 1–3 jours en général.

## Versions suivantes

Incrémente `version:` dans `pubspec.yaml` (ex. `1.0.1+2` — le `+N` est le
`versionCode` Android / build number iOS, il doit **toujours** augmenter),
rebuild, re-upload. Rien d'autre à toucher.
