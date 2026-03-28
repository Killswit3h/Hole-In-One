import 'pose_landmark.dart';

class PoseFrame {
  final int timestampMs;
  final List<PoseLandmark> landmarks;

  const PoseFrame({
    required this.timestampMs,
    required this.landmarks,
  });

  factory PoseFrame.fromJson(Map<String, dynamic> json) => PoseFrame(
        timestampMs: json['timestampMs'] as int,
        landmarks: (json['landmarks'] as List)
            .map((l) => PoseLandmark.fromJson(l as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'timestampMs': timestampMs,
        'landmarks': landmarks.map((l) => l.toJson()).toList(),
      };

  /// Returns landmark by type name, or null if not found / below likelihood threshold.
  PoseLandmark? getLandmark(String type, {double minLikelihood = 0.5}) {
    try {
      final lm = landmarks.firstWhere((l) => l.type == type);
      return lm.likelihood >= minLikelihood ? lm : null;
    } catch (_) {
      return null;
    }
  }
}
