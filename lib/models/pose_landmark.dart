class PoseLandmark {
  final String type;
  final double x; // normalized 0.0–1.0 (x / imageWidth)
  final double y; // normalized 0.0–1.0 (y / imageHeight)
  final double likelihood;

  const PoseLandmark({
    required this.type,
    required this.x,
    required this.y,
    required this.likelihood,
  });

  factory PoseLandmark.fromJson(Map<String, dynamic> json) => PoseLandmark(
        type: json['type'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        likelihood: (json['likelihood'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'x': x,
        'y': y,
        'likelihood': likelihood,
      };
}
