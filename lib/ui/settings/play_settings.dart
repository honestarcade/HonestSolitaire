/// The design's PLAY and SOUND settings as one immutable value, at the
/// design's defaults. The sound, music, haptics, animation and winnable
/// rows are carried now so M4 does not reshape the type; they take effect
/// in M4 and M5.
library;

class PlaySettings {
  const PlaySettings({
    this.oneTap = true,
    this.autoFinish = true,
    this.autoFlip = true,
    this.unlimitedUndo = true,
    this.winnableOnly = false,
    this.cardAnimations = true,
    this.sound = true,
    this.music = false,
    this.haptics = true,
  });

  final bool oneTap;
  final bool autoFinish;
  final bool autoFlip;
  final bool unlimitedUndo;
  final bool winnableOnly;
  final bool cardAnimations;
  final bool sound;
  final bool music;
  final bool haptics;

  PlaySettings copyWith({
    bool? oneTap,
    bool? autoFinish,
    bool? autoFlip,
    bool? unlimitedUndo,
    bool? winnableOnly,
    bool? cardAnimations,
    bool? sound,
    bool? music,
    bool? haptics,
  }) => PlaySettings(
    oneTap: oneTap ?? this.oneTap,
    autoFinish: autoFinish ?? this.autoFinish,
    autoFlip: autoFlip ?? this.autoFlip,
    unlimitedUndo: unlimitedUndo ?? this.unlimitedUndo,
    winnableOnly: winnableOnly ?? this.winnableOnly,
    cardAnimations: cardAnimations ?? this.cardAnimations,
    sound: sound ?? this.sound,
    music: music ?? this.music,
    haptics: haptics ?? this.haptics,
  );

  @override
  bool operator ==(Object other) =>
      other is PlaySettings &&
      other.oneTap == oneTap &&
      other.autoFinish == autoFinish &&
      other.autoFlip == autoFlip &&
      other.unlimitedUndo == unlimitedUndo &&
      other.winnableOnly == winnableOnly &&
      other.cardAnimations == cardAnimations &&
      other.sound == sound &&
      other.music == music &&
      other.haptics == haptics;

  @override
  int get hashCode => Object.hash(
    oneTap,
    autoFinish,
    autoFlip,
    unlimitedUndo,
    winnableOnly,
    cardAnimations,
    sound,
    music,
    haptics,
  );

  @override
  String toString() =>
      'PlaySettings(oneTap $oneTap, autoFinish $autoFinish, autoFlip $autoFlip, '
      'unlimitedUndo $unlimitedUndo, winnableOnly $winnableOnly, '
      'cardAnimations $cardAnimations, sound $sound, music $music, haptics $haptics)';
}
