/// Mode de séance.
enum SessionMode { pause, effort }

/// Phase d'un décompte.
enum Phase { pause, effort }

/// Étape courante à l'écran (à l'intérieur d'une séance).
enum SessionStep { setup, duration, doSet, timer, done }

/// Son joué à la fin d'une pause.
enum AlarmSound { triple, bell }

extension AlarmSoundAsset on AlarmSound {
  String get asset => switch (this) {
        AlarmSound.triple => 'sounds/triple.wav',
        AlarmSound.bell => 'sounds/bell.wav',
      };

  /// Nom du fichier dans le bundle iOS (Runner) pour le son de la notification
  /// planifiée — mêmes WAV que les assets, copiés dans le bundle par le script
  /// de setup Xcode (`ios/scripts/setup_ios_targets.rb`).
  String get iosSoundFile => switch (this) {
        AlarmSound.triple => 'triple.wav',
        AlarmSound.bell => 'bell.wav',
      };

  String get label => switch (this) {
        AlarmSound.triple => 'Triple bip',
        AlarmSound.bell => 'Cloche de salle',
      };
}
