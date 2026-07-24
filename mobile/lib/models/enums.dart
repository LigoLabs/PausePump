/// Mode de séance.
enum SessionMode { pause, effort }

/// Phase d'un décompte.
enum Phase { pause, effort }

/// Étape courante à l'écran (à l'intérieur d'une séance).
enum SessionStep { setup, duration, doSet, timer, done }

/// Son joué à la fin d'une pause (mêmes sons que le web, rendus en WAV par
/// `mobile/scripts/gen_sounds.js`).
enum AlarmSound { triple, marimba, bell, carillon, aigu, grave, montee }

extension AlarmSoundAsset on AlarmSound {
  String get asset => 'sounds/$name.wav';

  /// Nom du fichier dans le bundle iOS (Runner) pour le son de la notification
  /// planifiée — mêmes WAV que les assets, copiés dans le bundle par le script
  /// de setup Xcode (`ios/scripts/setup_ios_targets.rb`).
  String get iosSoundFile => '$name.wav';

  String get label => switch (this) {
        AlarmSound.triple => 'Triple bip',
        AlarmSound.marimba => 'Marimba',
        AlarmSound.bell => 'Cloche de salle',
        AlarmSound.carillon => 'Carillon',
        AlarmSound.aigu => 'Double aigu',
        AlarmSound.grave => 'Grave',
        AlarmSound.montee => 'Montée',
      };
}
