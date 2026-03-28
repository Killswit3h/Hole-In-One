import 'package:flutter/material.dart';

import '../models/pose_frame.dart';
import '../models/pose_landmark.dart';

/// Bone connections as pairs of landmark type names.
const List<List<String>> _boneConnections = [
  // Torso
  ['leftShoulder', 'rightShoulder'],
  ['leftShoulder', 'leftHip'],
  ['rightShoulder', 'rightHip'],
  ['leftHip', 'rightHip'],
  // Left arm
  ['leftShoulder', 'leftElbow'],
  ['leftElbow', 'leftWrist'],
  // Right arm
  ['rightShoulder', 'rightElbow'],
  ['rightElbow', 'rightWrist'],
  // Left leg
  ['leftHip', 'leftKnee'],
  ['leftKnee', 'leftAnkle'],
  // Right leg
  ['rightHip', 'rightKnee'],
  ['rightKnee', 'rightAnkle'],
];

class SkeletonPainter extends CustomPainter {
  final PoseFrame? frame;

  const SkeletonPainter({this.frame});

  @override
  void paint(Canvas canvas, Size size) {
    if (frame == null || frame!.landmarks.isEmpty) return;

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

    final jointPaint = Paint()
      ..color = const Color(0xFF81C784)
      ..style = PaintingStyle.fill;

    final jointLowPaint = Paint()
      ..color = const Color(0x8881C784)
      ..style = PaintingStyle.fill;

    // Draw bones first
    for (final bone in _boneConnections) {
      final start = _getLandmark(bone[0]);
      final end = _getLandmark(bone[1]);
      if (start == null || end == null) continue;

      final minLikelihood = start.likelihood < end.likelihood
          ? start.likelihood
          : end.likelihood;

      if (minLikelihood < 0.3) continue;

      final paint = minLikelihood >= 0.5 ? bonePaint : boneLowPaint;
      canvas.drawLine(
        _toScreen(start, size),
        _toScreen(end, size),
        paint,
      );
    }

    // Draw joints on top
    for (final lm in frame!.landmarks) {
      if (lm.likelihood < 0.3) continue;
      final isHighConf = lm.likelihood >= 0.5;
      final paint = isHighConf ? jointPaint : jointLowPaint;
      final radius = isHighConf ? 6.0 : 4.0;
      canvas.drawCircle(_toScreen(lm, size), radius, paint);
    }
  }

  PoseLandmark? _getLandmark(String type) {
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
  bool shouldRepaint(SkeletonPainter oldDelegate) =>
      oldDelegate.frame != frame;
}
