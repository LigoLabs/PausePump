import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/session_screen.dart';
import 'services/audio_service.dart';
import 'services/foreground_service.dart';
import 'services/live_activity_service.dart';
import 'services/notification_service.dart';
import 'services/storage.dart';
import 'services/wakelock_service.dart';
import 'services/watch_sync_service.dart';
import 'state/timer_controller.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final storage = await Storage.open();
  final audio = AudioService();
  final notifications = NotificationService();
  await audio.init();
  await notifications.init();

  final controller = TimerController(
    storage: storage,
    audio: audio,
    notifications: notifications,
    wakelock: WakelockService(),
    foreground: ForegroundService(),
    liveActivity: LiveActivityService(),
    watchSync: WatchSyncService(),
  );

  runApp(
    ChangeNotifierProvider.value(value: controller, child: const PausePumpApp()),
  );
}

final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class PausePumpApp extends StatelessWidget {
  const PausePumpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PausePump',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: buildTheme(),
      home: const _Root(),
    );
  }
}

/// Bascule accueil / séance selon l'état du contrôleur, et affiche les
/// messages éphémères (snackbar façon web : fond accent, texte sombre).
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TimerController>();
    final toast = c.consumeToast();
    if (toast != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _messengerKey.currentState?.showSnackBar(SnackBar(
          content: Text(toast,
              style: const TextStyle(
                  color: Color(0xFF04130F), fontWeight: FontWeight.w700)),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ));
      });
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: c.inSession ? const SessionScreen() : const HomeScreen(),
    );
  }
}
