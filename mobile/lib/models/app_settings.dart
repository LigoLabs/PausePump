import 'enums.dart';

/// Durées de timer par défaut (secondes) — mêmes valeurs que le web.
const List<int> kDefaultTimers = [30, 45, 60, 90, 120, 150, 180, 300];

/// Réglages persistés (l'équivalent de `settings` côté web).
class AppSettings {
  const AppSettings({
    this.keepAwake = true,
    this.vibrate = true,
    this.sound = true,
    this.volume = 1.0,
    this.alarm = AlarmSound.triple,
    this.notify = true,
    this.notifySound = true,
    this.prepCountdown = true,
    this.doSetScreen = true,
    this.endScreen = true,
    this.timers = kDefaultTimers,
  });

  final bool keepAwake;
  final bool vibrate;
  final bool sound;
  final double volume; // 0..1
  final AlarmSound alarm;
  final bool notify;
  final bool notifySound; // son système de la notification de fin
  final bool prepCountdown; // décompte 3-2-1 avant l'effort (mode étape par étape)
  final bool doSetScreen; // écran « Fais ta série » (mode Pause seule)
  final bool endScreen; // écran de fin de séance
  final List<int> timers; // durées enregistrées (secondes), éditables

  /// Durées triées pour l'affichage des grilles (le web trie aussi).
  List<int> get sortedTimers => [...timers]..sort();

  AppSettings copyWith({
    bool? keepAwake,
    bool? vibrate,
    bool? sound,
    double? volume,
    AlarmSound? alarm,
    bool? notify,
    bool? notifySound,
    bool? prepCountdown,
    bool? doSetScreen,
    bool? endScreen,
    List<int>? timers,
  }) {
    return AppSettings(
      keepAwake: keepAwake ?? this.keepAwake,
      vibrate: vibrate ?? this.vibrate,
      sound: sound ?? this.sound,
      volume: volume ?? this.volume,
      alarm: alarm ?? this.alarm,
      notify: notify ?? this.notify,
      notifySound: notifySound ?? this.notifySound,
      prepCountdown: prepCountdown ?? this.prepCountdown,
      doSetScreen: doSetScreen ?? this.doSetScreen,
      endScreen: endScreen ?? this.endScreen,
      timers: timers ?? this.timers,
    );
  }

  Map<String, dynamic> toJson() => {
        'keepAwake': keepAwake,
        'vibrate': vibrate,
        'sound': sound,
        'volume': volume,
        'alarm': alarm.name,
        'notify': notify,
        'notifySound': notifySound,
        'prepCountdown': prepCountdown,
        'doSetScreen': doSetScreen,
        'endScreen': endScreen,
        'timers': timers,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    final rawTimers = (j['timers'] as List?)
        ?.whereType<num>()
        .map((n) => n.toInt())
        .toList();
    return AppSettings(
      keepAwake: j['keepAwake'] as bool? ?? true,
      vibrate: j['vibrate'] as bool? ?? true,
      sound: j['sound'] as bool? ?? true,
      volume: (j['volume'] as num?)?.toDouble() ?? 1.0,
      alarm: AlarmSound.values.firstWhere(
        (a) => a.name == j['alarm'],
        orElse: () => AlarmSound.triple,
      ),
      notify: j['notify'] as bool? ?? true,
      notifySound: j['notifySound'] as bool? ?? true,
      prepCountdown: j['prepCountdown'] as bool? ?? true,
      doSetScreen: j['doSetScreen'] as bool? ?? true,
      endScreen: j['endScreen'] as bool? ?? true,
      timers: (rawTimers == null || rawTimers.isEmpty) ? kDefaultTimers : rawTimers,
    );
  }
}
