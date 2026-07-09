# PausePump — app mobile (Flutter) + Apple Watch

App native **Android + iOS** de PausePump, écrite en Flutter, plus une **app
Apple Watch native (SwiftUI)** et une **Live Activity iOS** (compte à rebours
natif sur l'écran verrouillé / Dynamic Island). La version **web** reste la PWA
à la racine du dépôt (`../index.html`).

Les coquilles `android/` **et** `ios/` sont versionnées (elles contiennent la
config native : bridges Swift, extension widget, app watch). Seuls les shells
web/desktop restent générés à la demande (cf. `.gitignore`).

> **Dev sous Windows ?** Tout le code (Dart, Swift, Ruby) s'édite et se teste
> ici : `flutter test` pour le Dart, le **CI GitHub Actions** compile l'iOS
> (`macos`) et exécute les tests Swift du moteur watch. Le passage sur un Mac
> n'est nécessaire que pour installer sur un iPhone réel — voir
> [MAC_SETUP.md](MAC_SETUP.md).

## Prérequis
- [Flutter](https://docs.flutter.dev/get-started/install) (canal stable, Dart ≥ 3.3)
- **iOS** : un Mac avec Xcode + CocoaPods
- **Android** : Android Studio (SDK + un émulateur ou un appareil)

## 1) Récupérer les dépendances

Les coquilles `android/` et `ios/` sont dans git : il suffit de

```bash
flutter pub get
```

(`flutter create . --org com.ligolabs --project-name pausepump --platforms=...`
ne sert plus qu'à régénérer un shell après une grosse montée de version
Flutter ; vérifier ensuite le diff git et relancer
`ruby ios/scripts/setup_ios_targets.rb` côté iOS.)

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

### iOS — déjà committé
`ios/Runner/Info.plist` contient `UIBackgroundModes: [audio]` (son écran
verrouillé) et `NSSupportsLiveActivities`. Les targets **PausePumpWidgets**
(Live Activity) et **PausePumpWatch** (app montre) sont créées dans le projet
Xcode par `ruby ios/scripts/setup_ios_targets.rb` (idempotent, exécuté par le
CI et une fois sur le Mac) — voir [MAC_SETUP.md](MAC_SETUP.md).

## Architecture

```
lib/
  main.dart                  # bootstrap services + Provider, bascule accueil/séance
  theme.dart                 # palette de la marque (thème sombre)
  models/                    # enums + AppSettings (persisté)
  state/timer_controller.dart# machine à états (port de `advancePhase`) + timeline + services
  services/                  # storage, audio, notifications, wakelock,
                             # foreground (chrono natif Android),
                             # live_activity (chrono natif iOS),
                             # watch_sync (config → Apple Watch)
  screens/ · widgets/        # UI (étapes : setup/duration/doSet/timer/done)
  assets/sounds/             # bips WAV (triple, cloche, tick, go)

ios/
  Runner/                    # AppDelegate + bridges Swift :
                             #   LiveActivityBridge (ActivityKit, canal pausepump/live_activity)
                             #   WatchSyncBridge   (WCSession,  canal pausepump/watch_sync)
                             #   RestTimerAttributes (état partagé avec le widget)
  PausePumpWidgets/          # extension WidgetKit : Live Activity (lock screen + Dynamic Island)
  PausePumpWatch/            # app watchOS SwiftUI (séance autonome au poignet)
  scripts/setup_ios_targets.rb # crée les targets widget/watch dans le pbxproj (idempotent)

watch_engine/                # package SwiftPM : machine à états pure Swift
                             # (port de timer_controller.dart), testée par `swift test`
```

**Trois implémentations, une seule logique** : la machine à états `advancePhase`
existe en JS (web), en Dart (`timer_controller.dart`) et en Swift
(`watch_engine`). Toute modification de la logique de transition doit être
répercutée dans les trois.

### Chrono natif en arrière-plan (le « truc » par plateforme)
- **Android** : foreground service + `setChronometerCountDown` → la notification
  défile sans réveiller le Dart (`TimerService.kt`).
- **iOS** : Live Activity + `Text(timerInterval:)` → l'écran verrouillé et la
  Dynamic Island défilent sans réveiller l'app ; la notification **planifiée**
  (`zonedSchedule`, son WAV custom, time-sensitive) sonne à l'heure pile.
  Depuis watchOS 11, la Live Activity apparaît aussi dans le **Smart Stack** de
  l'Apple Watch, sans installer l'app watch.
- **watchOS** : app autonome — le moteur recalcule tout depuis `endDate`
  (jamais de compteur décrémenté) et une notification locale garantit
  l'haptique de fin même app suspendue.

## Roadmap native (prochaines étapes)
- ~~Foreground service Android (chrono natif dans la notification)~~ ✅
- ~~iOS Live Activities (lock screen + Dynamic Island)~~ ✅
- ~~App Apple Watch (séance autonome, picker de durées en swipe)~~ ✅
- Écran **Réglages** complet (sons, vibration, volume, écrans optionnels).
- Sélecteur de **son** + aperçu, et plus de timbres.
- Complications montre (lancement rapide) & App Intents (Siri « lance ma pause »).
- Montre : écran de réglage des durées **Effort + Pause** (v1 : durées par
  défaut en enchaînement auto) et pré-planification de **toutes** les
  notifications de la chaîne auto (v1 : seule la fin de la phase en cours est
  garantie poignet baissé — le mode « Pause seule », l'usage principal, n'est
  pas concerné : chaque pause part d'un tap).
