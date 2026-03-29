import 'package:flutter/material.dart';

import '../models/pose_frame.dart';
import '../models/pose_landmark.dart';

const List<List<String>> _bones = [
  ['leftShoulder', 'rightShoulder'],
  ['leftShoulder', 'leftHip'],
  ['rightShoulder', 'rightHip'],
  ['leftHip', 'rightHip'],
  ['leftShoulder', 'leftElbow'],
  ['leftElbow', 'leftWrist'],
  ['rightShoulder', 'rightElbow'],
  ['rightElbow', 'rightWrist'],
  ['leftHip', 'leftKnee'],
  ['leftKnee', 'leftAnkle'],
  ['rightHip', 'rightKnee'],
  ['rightKnee', 'rightAnkle'],
];

class SkeletonPainter extends CustomPainter {
  final PoseFrame? frame;

  /// Landmark types that should be drawn in the fault (red/orange) colour.
  final Set<String> faultedLandmarks;

  const SkeletonPainter({
    this.frame,
    this.faultedLandmarks = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (frame == null || frame!.landmarks.isEmpty) return;

    // Normal bone paint
    final bonePaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final boneLowPaint = Paint()
      ..color = const Color(0x664CAF50)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Fault bone paint
    final faultBonePaint = Paint()
      ..color = const Color(0xFFFF5252)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Joint paints
    final jointPaint = Paint()
      ..color = const Color(0xFF81C784)
      ..style = PaintingStyle.fill;

    final jointLowPaint = Paint()
      ..color = const Color(0x8881C784)
      ..style = PaintingStyle.fill;

    final faultJointPaint = Paint()
      ..color = const Color(0xFFFF5252)
      ..style = PaintingStyle.fill;

    // Draw bones
    for (final bone in _bones) {
      final start = _get(bone[0]);
      final end = _get(bone[1]);
      if (start == null || end == null) continue;

      final minLikelihood =
          start.likelihood < end.likelihood ? start.likelihood : end.likelihood;
      if (minLikelihood < 0.3) continue;

      final isFault =
          faultedLandmarks.contains(bone[0]) || faultedLandmarks.contains(bone[1]);

      final paint = isFault
          ? faultBonePaint
          : (minLikelihood >= 0.5 ? bonePaint : boneLowPaint);

      canvas.drawLine(_toScreen(start, size), _toScreen(end, size), paint);
    }

    // Draw joints on top
    for (final lm in frame!.landmarks) {
      if (lm.likelihood < 0.3) continue;
      final isFault = faultedLandmarks.contains(lm.type);
      final high = lm.likelihood >= 0.5;

      Paint paint;
      double radius;
      if (isFault) {
        paint = faultJointPaint;
        radius = high ? 7.0 : 5.0;
      } else {
        paint = high ? jointPaint : jointLowPaint;
        radius = high ? 6.0 : 4.0;
      }
      canvas.drawCircle(_toScreen(lm, size), radius, paint);
    }
  }

  PoseLandmark? _get(String type) {
    if (frame == null) return null;
    try {
      return frame!.landmarks.firstWhere((l) => l.type == type);
    } catch (_) {
      return null;
    }
  }

  Offset _toScreen(PoseLandmark lm, Size size) =>
      Offset(lm.x * size.width, lm.y * size.height);

  @override
  bool shouldRepaint(SkeletonPainter old) =>
      old.frame != frame || old.faultedLandmarks != faultedLandmarks;
}
