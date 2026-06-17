# PausePump — app mobile (Flutter)

App native **Android + iOS** de PausePump, écrite en Flutter. La version **web**
reste la PWA à la racine du dépôt (`../index.html`). Ce dossier ne contient que
le **code Dart** ; les coquilles natives (`android/`, `ios/`) sont générées
localement (non versionnées, cf. `.gitignore`).

## Prérequis
- [Flutter](https://docs.flutter.dev/get-started/install) (canal stable, Dart ≥ 3.3)
- **iOS** : un Mac avec Xcode + CocoaPods
- **Android** : Android Studio (SDK + un émulateur ou un appareil)

## 1) Générer les coquilles natives

Depuis ce dossier `mobile/` :

```bash
flutter create . --org com.ligolabs --project-name pausepump --platforms=android,ios
# `flutter create` écrase pubspec.yaml et lib/main.dart par les templates :
# on restaure nos versions (tout est dans git) :
git checkout -- pubspec.yaml analysis_options.yaml lib/
flutter pub get
```

## 2) Lancer

```bash
flutter run                 # appareil/émulateur connecté
flutter run -d ios          # iOS
flutter run -d android      # Android
```

## 3) Config native (à faire une fois, après `flutter create`)

### Android — `android/app/src/main/AndroidManifest.xml`
Dans `<manifest>` (au-dessus de `<application>`) :
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.VIBRATE"/>
```
Et les receivers requis par `flutter_local_notifications` (dans `<application>`) :
```xml
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED"/>
  </intent-filter>
</receiver>
```

### iOS — `ios/Runner/Info.plist`
Pour que le son joue écran verrouillé en arrière-plan :
```xml
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>
```

## Architecture (`lib/`)
```
main.dart                  # bootstrap services + Provider, bascule accueil/séance
theme.dart                 # palette de la marque (thème sombre)
models/                    # enums + AppSettings (persisté)
state/timer_controller.dart# machine à états (port de `advancePhase`) + timeline + services
services/                  # storage, audio, notifications, wakelock
screens/                   # home, session (étapes : setup/duration/doSet/timer/done)
widgets/                   # timeline, ring, grille de durées, écran « Fais ta série »…
assets/sounds/             # bips WAV (triple, cloche, tick, go)
```

## Roadmap native (prochaines étapes)
- **Foreground service Android** (`flutter_foreground_task`) → notification *ongoing*
  avec **chrono natif qui défile** (le « truc » de Gym Rest Timer), sans réveiller le Dart.
- **iOS Live Activities** (Dynamic Island) pour le timer en cours.
- Écran **Réglages** complet (sons, vibration, volume, écrans optionnels).
- Sélecteur de **son** + aperçu, et plus de timbres.
