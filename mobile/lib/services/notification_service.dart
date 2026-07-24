import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/enums.dart';

/// Notifications locales. Le décompte ne tourne pas en arrière-plan, mais une
/// notification **planifiée** est déclenchée par l'OS à l'heure pile (même app
/// fermée) → c'est la fin de pause fiable, l'équivalent de l'app native.
///
/// Le plugin est créé paresseusement dans [init] (testable sans natif).
class NotificationService {
  FlutterLocalNotificationsPlugin? _plugin;

  /// IDs en rotation pour la notif de fin : en arrière-plan (process vivant
  /// sous le foreground service), la phase suivante est planifiée par le code
  /// Dart AVANT que l'alarme de la phase finie ne soit forcément délivrée —
  /// réutiliser le même ID écraserait cette alarme (fin muette). Les IDs
  /// périmés sont purgés par [cancelAll] au retour au 1er plan.
  static const List<int> _endIds = [1, 2, 3, 4];
  int _endIdx = 0;
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

  /// Variante « bip de l'app » : la notification joue le WAV de l'alarme
  /// choisie (copié dans `android/app/src/main/res/raw/` par
  /// `scripts/gen_sounds.js`) au lieu du son système — même bip qu'au premier
  /// plan. Le son étant une propriété du CANAL (figée à sa création), il faut
  /// un canal par alarme. Flux « alarme » : sonne même si les notifications
  /// sont en mode discret.
  static AndroidNotificationDetails _androidEndWithBeep(AlarmSound alarm) {
    return AndroidNotificationDetails(
      'pausepump_end_${alarm.name}',
      'Fin de pause — ${alarm.label}',
      channelDescription: 'Signale la fin du temps de repos (bip de l\'app)',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(alarm.name),
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
  }

  /// Variante muette : sur Android le son est une propriété du CANAL (figée à
  /// sa création), donc « Son à la notification » désactivé = autre canal.
  static const AndroidNotificationDetails _androidEndSilent =
      AndroidNotificationDetails(
    'pausepump_end_silent',
    'Fin de pause (silencieuse)',
    channelDescription: 'Signale la fin du temps de repos, sans son',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    playSound: false,
  );

  /// Le son est celui de l'alarme choisie ([alarm] non nul) : WAV bundlé dans
  /// Runner côté iOS, ressource `raw` côté Android. La notif est
  /// « time-sensitive » (iOS) pour sonner malgré les modes de concentration.
  static NotificationDetails _endDetails(AlarmSound? alarm, bool playSound) {
    final android = !playSound
        ? _androidEndSilent
        : (alarm != null ? _androidEndWithBeep(alarm) : _androidEnd);
    return NotificationDetails(
      android: android,
      iOS: DarwinNotificationDetails(
        presentSound: playSound,
        presentAlert: true,
        sound: playSound ? alarm?.iosSoundFile : null,
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

  /// Planifie la notif de fin de pause à [when]. [alarm] : bip de l'app à
  /// jouer (null = son système). [playSound] : réglage
  /// « Son à la notification ».
  Future<void> scheduleEnd(
    DateTime when, {
    required String body,
    AlarmSound? alarm,
    bool playSound = true,
  }) async {
    final plugin = _plugin;
    if (plugin == null) return;
    final at = tz.TZDateTime.from(when, tz.local);
    // ID neuf à chaque planification : surtout NE PAS annuler la précédente —
    // en enchaînement auto arrière-plan elle peut être en cours de délivrance
    // (c'est le bip de la phase qui vient de finir).
    _endIdx = (_endIdx + 1) % _endIds.length;
    try {
      await plugin.zonedSchedule(
        _endIds[_endIdx],
        'PausePump ⏱️',
        body,
        at,
        _endDetails(alarm, playSound),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Permission d'alarme exacte refusée → on ignore (géré en 1er plan).
    }
  }

  Future<void> cancelEnd() async => _plugin?.cancel(_endIds[_endIdx]);
  Future<void> cancelAll() async => _plugin?.cancelAll();
}
