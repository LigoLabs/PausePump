import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pausepump/screens/home_screen.dart';
import 'package:pausepump/screens/session_screen.dart';
import 'package:pausepump/services/audio_service.dart';
import 'package:pausepump/services/foreground_service.dart';
import 'package:pausepump/services/live_activity_service.dart';
import 'package:pausepump/services/notification_service.dart';
import 'package:pausepump/services/storage.dart';
import 'package:pausepump/services/wakelock_service.dart';
import 'package:pausepump/services/watch_sync_service.dart';
import 'package:pausepump/state/timer_controller.dart';
import 'package:pausepump/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<TimerController> makeController() async {
  SharedPreferences.setMockInitialValues({});
  final storage = await Storage.open();
  return TimerController(
    storage: storage,
    audio: AudioService(),
    notifications: NotificationService(),
    wakelock: WakelockService(),
    foreground: ForegroundService(),
    liveActivity: LiveActivityService(supported: false),
    watchSync: WatchSyncService(supported: false),
  );
}

Widget app(TimerController c) {
  return ChangeNotifierProvider<TimerController>.value(
    value: c,
    child: MaterialApp(
      theme: buildTheme(),
      home: Consumer<TimerController>(
        builder: (_, ctrl, __) =>
            ctrl.inSession ? const SessionScreen() : const HomeScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('Accueil → séance → « Fais ta série » → choix de durée se construisent',
      (tester) async {
    // Taille d'un téléphone réaliste (portrait).
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = await makeController();
    await tester.pumpWidget(app(c));

    // Accueil
    expect(find.text("C'est parti"), findsOneWidget);
    expect(find.text('Pause seule'), findsOneWidget);

    // Lancer la séance (3 séries par défaut, mode Pause seule)
    await tester.ensureVisible(find.text("C'est parti"));
    await tester.tap(find.text("C'est parti"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Écran « Fais ta série »
    expect(find.text('Fais ta 1re série'), findsOneWidget);
    expect(find.text("J'ai fait ma série"), findsOneWidget);

    // Valider → on quitte l'écran animé pour le choix de durée
    await tester.tap(find.text("J'ai fait ma série"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Choisis ta pause'), findsOneWidget);
    expect(c.seriesRemaining, 2);

    c.dispose();
  });
}
