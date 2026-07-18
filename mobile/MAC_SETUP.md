# Mise en route côté Mac — iOS + watchOS

Le développement PausePump se fait sous Windows : le repo committe donc un
shell iOS Flutter « brut » (`mobile/ios/`) dans lequel les sources natives
(Live Activity, app watchOS, sons) ne sont **pas encore câblées**. Le câblage
du projet Xcode est entièrement scripté — **ne modifiez jamais
`project.pbxproj` à la main.**

## Prérequis

- macOS avec **Xcode 15+** (SDK iOS 16.2 minimum pour les Live Activities).
- **Flutter** (canal stable — la CI utilise la 3.44.2).
- La gem Ruby **`xcodeproj`** :
  - déjà présente si vous avez CocoaPods (`gem install cocoapods`) ;
  - sinon : `gem install xcodeproj --no-document` (avec le Ruby système,
    préfixez par `sudo`, ou utilisez un Ruby Homebrew/rbenv).

## Étapes

```bash
cd mobile

# 1. Dépendances Flutter
flutter pub get

# 2. Câbler le projet Xcode : ajoute aux targets les ponts natifs, crée
#    l'extension widget (Live Activity) et l'app watchOS, embarque les sons.
ruby ios/scripts/setup_ios_targets.rb

# 3. Ouvrir le workspace (PAS le .xcodeproj)
open ios/Runner.xcworkspace
```

Dans Xcode ensuite :

1. **Signature** : pour chacune des **3 targets** — `Runner`,
   `PausePumpWidgets`, `PausePumpWatch` — ouvrez l'onglet
   *Signing & Capabilities* et sélectionnez votre **équipe** (Team). Le style
   de signature est déjà en *Automatic* ; les bundle identifiers sont
   `com.ligolabs.pausepump`, `.widgets` et `.watchkitapp`.
2. **Lancer sur iPhone** : branchez l'iPhone, sélectionnez le scheme `Runner`
   et votre appareil, puis Run (`flutter run` fonctionne aussi une fois la
   signature réglée).
3. **App watch** : elle s'installe via l'app **Watch** de l'iPhone (onglet
   *Ma montre* → section des apps disponibles), ou automatiquement si
   « Installation automatique des apps » est activée.

## Bon à savoir

- **Live Activities** : visibles dès **iOS 16.2** (écran verrouillé +
  Dynamic Island). Le décompte apparaît aussi dans le **Smart Stack de
  l'Apple Watch (watchOS 11+)**, relayé depuis l'iPhone, *même sans installer
  l'app watch*.
- **Le script est idempotent** : relancez-le autant de fois que nécessaire, il
  ne duplique rien. **Relancez-le** dès que de nouveaux fichiers Swift natifs
  sont ajoutés (`ios/Runner/`, `ios/PausePumpWidgets/`, `ios/PausePumpWatch/`,
  `watch_engine/`).
- **Après `flutter create`** (régénération du shell iOS) : le pbxproj revient
  à l'état « template » ; relancez le script puis **committez le
  `project.pbxproj` résultant AINSI QUE les fichiers d'entitlements créés par
  le script** (`ios/Runner/Runner.entitlements` et
  `ios/PausePumpWatch/PausePumpWatch.entitlements` — notifications
  time-sensitive) — ou laissez la CI s'en charger (le job `build-ios` de
  `.github/workflows/mobile-build.yml` exécute le script avant chaque build).
- **TestFlight / distribution** : nécessite un compte **Apple Developer**
  payant. Le build de la CI (`--no-codesign`) sert uniquement de vérification
  de compilation.

## Vérifier sans Xcode (mêmes commandes que la CI)

Après `ruby ios/scripts/setup_ios_targets.rb`, depuis `mobile/` :

```bash
# 1. Contrôle éclair : les targets générées doivent avoir un nom de produit.
#    Attendu : « PausePumpWatch.app » et « PausePumpWidgets.appex ».
#    Un « .app » / « .appex » nu = PRODUCT_NAME non résolu → le build iOS
#    échouera sur « Multiple commands produce … » (voir README.md).
xcodebuild -project ios/Runner.xcodeproj -target PausePumpWatch \
  -configuration Debug -sdk watchsimulator -showBuildSettings \
  | grep -E 'PRODUCT_NAME|FULL_PRODUCT_NAME|EXECUTABLE_PATH'
xcodebuild -project ios/Runner.xcodeproj -target PausePumpWidgets \
  -configuration Debug -sdk iphonesimulator -showBuildSettings \
  | grep -E 'PRODUCT_NAME|FULL_PRODUCT_NAME'

# 2. Compilation isolée de l'app watchOS (ni Flutter, ni CocoaPods, ni
#    signature). `-target` et non `-scheme` : le script ne crée pas de scheme
#    partagé pour la montre — et `-derivedDataPath` est alors refusé par
#    xcodebuild (il exige `-scheme`).
xcodebuild -project ios/Runner.xcodeproj -target PausePumpWatch \
  -configuration Debug -sdk watchsimulator \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build

# 3. Build iOS complet (compile les ponts Swift + l'appex + la montre, et
#    exécute les phases « Embed Foundation Extensions » / « Embed Watch
#    Content »). Flutter détecte la companion watchOS via
#    ios/PausePumpWatch/Info.plist (WKCompanionAppBundleIdentifier =
#    com.ligolabs.pausepump) et omet alors « -sdk iphoneos ».
flutter build ios --debug --no-codesign

# 4. L'embarquement a-t-il réellement eu lieu ?
ls build/ios/iphoneos/Runner.app/PlugIns/PausePumpWidgets.appex
ls build/ios/iphoneos/Runner.app/Watch/PausePumpWatch.app
```

Pour un build **simulateur** avec companion watchOS, Flutter exige un
identifiant d'appareil : `flutter build ios --debug --simulator -d <UDID>`
(sans `-d`, l'outil s'arrête sur « A device ID is required to build an app with
a watchOS companion app »). Le CI vise l'appareil générique, donc non concerné.

Ce que le CI **ne** vérifie **pas**, et qui demande un Mac + un compte
développeur : la signature réelle des trois targets (provisioning profiles,
App Groups), l'installation de l'app watch depuis l'app Watch de l'iPhone, le
rendu effectif de la Live Activity / du Dynamic Island, et la synchronisation
`WCSession` iPhone ↔ montre.
