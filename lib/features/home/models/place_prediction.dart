class PlacePrediction {
  final String description;
  final String placeId;
  final String mainText;
  final String secondaryText;

  const PlacePrediction({
    required this.description,
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final formatting =
        (json['structured_formatting'] as Map<String, dynamic>?) ?? {};

    return PlacePrediction(
      description: json['description'] ?? '',
      placeId: json['place_id'] ?? '',
      mainText: formatting['main_text'] ?? '',
      secondaryText: formatting['secondary_text'] ?? '',
    );
  }
}
