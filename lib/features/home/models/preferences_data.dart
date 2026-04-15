class PreferencesData {
  final double shrines;
  final double shopping;
  final double cafes;
  final double parks;
  final double addedDuration;

  const PreferencesData({
    this.shrines = 2,
    this.shopping = 2,
    this.cafes = 2,
    this.parks = 2,
    this.addedDuration = 100,
  });

  @override
  bool operator ==(Object other) =>
      other is PreferencesData &&
      other.shrines == shrines &&
      other.shopping == shopping &&
      other.cafes == cafes &&
      other.parks == parks &&
      other.addedDuration == addedDuration;

  @override
  int get hashCode => Object.hash(shrines, shopping, cafes, parks, addedDuration);

  PreferencesData copyWith({
    double? shrines,
    double? shopping,
    double? cafes,
    double? parks,
    double? addedDuration,
  }) {
    return PreferencesData(
      shrines: shrines ?? this.shrines,
      shopping: shopping ?? this.shopping,
      cafes: cafes ?? this.cafes,
      parks: parks ?? this.parks,
      addedDuration: addedDuration ?? this.addedDuration,
    );
  }
}
