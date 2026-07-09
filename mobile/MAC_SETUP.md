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
