import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/session_screen.dart';
import 'services/audio_service.dart';
import 'services/notification_service.dart';
import 'services/storage.dart';
import 'services/wakelock_service.dart';
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
  );

  runApp(
    ChangeNotifierProvider.value(value: controller, child: const PausePumpApp()),
  );
}

class PausePumpApp extends StatelessWidget {
  const PausePumpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PausePump',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _Root(),
    );
  }
}

/// Bascule accueil / séance selon l'état du contrôleur.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final inSession = context.select<TimerController, bool>((c) => c.inSession);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: inSession ? const SessionScreen() : const HomeScreen(),
    );
  }
}
