import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Notifications locales. Le décompte ne tourne pas en arrière-plan, mais une
/// notification **planifiée** est déclenchée par l'OS à l'heure pile (même app
/// fermée) → c'est la fin de pause fiable, l'équivalent de l'app native.
///
/// Le plugin est créé paresseusement dans [init] (testable sans natif).
class NotificationService {
  FlutterLocalNotificationsPlugin? _plugin;
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

  /// iOS : le son est celui de l'alarme choisie (WAV bundlé dans Runner) et la
  /// notif est « time-sensitive » pour sonner malgré les modes de concentration.
  static NotificationDetails _endDetails(String? iosSound) {
    return NotificationDetails(
      android: _androidEnd,
      iOS: DarwinNotificationDetails(
        presentSound: true,
        presentAlert: true,
        sound: iosSound,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  Future<void> init() async {
    if (_ready) return;
    final plugin = FlutterLocalNotificationsPlugin();
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(
          tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (_) {
      // Repli : UTC.
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await plugin.initialize(settings);
    _plugin = plugin;
    _ready = true;
  }

  /// Demande la permission (Android 13+, iOS). À appeler sur un geste utilisateur.
  Future<void> requestPermission() async {
    final plugin = _plugin;
    if (plugin == null) return;
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Planifie la notif de fin de pause à [when]. [iosSound] : nom du fichier
  /// son dans le bundle iOS (null = son système).
  Future<void> scheduleEnd(
    DateTime when, {
    required String body,
    String? iosSound,
  }) async {
    final plugin = _plugin;
    if (plugin == null) return;
    final at = tz.TZDateTime.from(when, tz.local);
    try {
      await plugin.zonedSchedule(
        _endId,
        'PausePump ⏱️',
        body,
        at,
        _endDetails(iosSound),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Permission d'alarme exacte refusée → on ignore (géré en 1er plan).
    }
  }

  Future<void> cancelEnd() async => _plugin?.cancel(_endId);
  Future<void> cancelAll() async => _plugin?.cancelAll();
}
