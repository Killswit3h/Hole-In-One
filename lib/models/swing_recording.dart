class SwingRecording {
  final String id;
  final String videoPath;
  final String posesPath;
  final DateTime timestamp;
  final int durationMs;

  const SwingRecording({
    required this.id,
    required this.videoPath,
    required this.posesPath,
    required this.timestamp,
    required this.durationMs,
  });

  factory SwingRecording.fromJson(Map<String, dynamic> json) => SwingRecording(
        id: json['id'] as String,
        videoPath: json['videoPath'] as String,
        posesPath: json['posesPath'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        durationMs: json['durationMs'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'videoPath': videoPath,
        'posesPath': posesPath,
        'timestamp': timestamp.toIso8601String(),
        'durationMs': durationMs,
      };
}
