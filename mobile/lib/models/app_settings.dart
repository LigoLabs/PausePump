import 'enums.dart';

/// Réglages persistés (l'équivalent de `settings` côté web).
class AppSettings {
  const AppSettings({
    this.keepAwake = true,
    this.vibrate = true,
    this.sound = true,
    this.volume = 1.0,
    this.alarm = AlarmSound.triple,
    this.notify = true,
    this.prepCountdown = true,
    this.doSetScreen = true,
    this.endScreen = true,
  });

  final bool keepAwake;
  final bool vibrate;
  final bool sound;
  final double volume; // 0..1
  final AlarmSound alarm;
  final bool notify;
  final bool prepCountdown; // décompte 3-2-1 avant l'effort (mode étape par étape)
  final bool doSetScreen; // écran « Fais ta série » (mode Pause seule)
  final bool endScreen; // écran de fin de séance

  AppSettings copyWith({
    bool? keepAwake,
    bool? vibrate,
    bool? sound,
    double? volume,
    AlarmSound? alarm,
    bool? notify,
    bool? prepCountdown,
    bool? doSetScreen,
    bool? endScreen,
  }) {
    return AppSettings(
      keepAwake: keepAwake ?? this.keepAwake,
      vibrate: vibrate ?? this.vibrate,
      sound: sound ?? this.sound,
      volume: volume ?? this.volume,
      alarm: alarm ?? this.alarm,
      notify: notify ?? this.notify,
      prepCountdown: prepCountdown ?? this.prepCountdown,
      doSetScreen: doSetScreen ?? this.doSetScreen,
      endScreen: endScreen ?? this.endScreen,
    );
  }

  Map<String, dynamic> toJson() => {
        'keepAwake': keepAwake,
        'vibrate': vibrate,
        'sound': sound,
        'volume': volume,
        'alarm': alarm.name,
        'notify': notify,
        'prepCountdown': prepCountdown,
        'doSetScreen': doSetScreen,
        'endScreen': endScreen,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
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
      prepCountdown: j['prepCountdown'] as bool? ?? true,
      doSetScreen: j['doSetScreen'] as bool? ?? true,
      endScreen: j['endScreen'] as bool? ?? true,
    );
  }
}
