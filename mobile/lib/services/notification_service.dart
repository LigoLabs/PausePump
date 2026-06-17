import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Notifications locales. Le décompte JS ne tourne pas en arrière-plan, mais une
/// notification **planifiée** est déclenchée par l'OS à l'heure pile (même app
/// fermée) → c'est la fin de pause fiable, l'équivalent de l'app native.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _endId = 1;
  bool _ready = false;

  static const AndroidNotificationDetails _androidEnd =
      AndroidNotificationDetails(
    'pausepump_end',
    'Fin de pause',
    channelDescription: 'Signale la fin du temps de repos',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    playSound: true,
  );

  static const NotificationDetails _endDetails = NotificationDetails(
    android: _androidEnd,
    iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true),
  );

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (_) {
      // Repli : UTC. Les notifs resteront cohérentes entre elles.
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);
    _ready = true;
  }

  /// Demande la permission (Android 13+, iOS). À appeler sur un geste utilisateur.
  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Planifie la notif de fin de pause à [when].
  Future<void> scheduleEnd(DateTime when, {required String body}) async {
    if (!_ready) return;
    final at = tz.TZDateTime.from(when, tz.local);
    try {
      await _plugin.zonedSchedule(
        _endId,
        'PausePump ⏱️',
        body,
        at,
        _endDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // Permission d'alarme exacte refusée → on ignore (l'app gère en 1er plan).
    }
  }

  Future<void> cancelEnd() async {
    if (_ready) await _plugin.cancel(_endId);
  }

  Future<void> cancelAll() async {
    if (_ready) await _plugin.cancelAll();
  }
}
