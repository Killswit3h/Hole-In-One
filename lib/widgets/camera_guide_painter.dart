import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/swing_analysis_result.dart';

/// Draws camera alignment guides on the live camera preview
/// so the user knows exactly where to stand.
class CameraGuidePainter extends CustomPainter {
  final SwingAngle angle;

  const CameraGuidePainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final accentPaint = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // ── Thirds grid (faint) ──────────────────────────────────────────────────
    for (final frac in [1 / 3, 2 / 3]) {
      canvas.drawLine(
        Offset(w * frac, 0),
        Offset(w * frac, h),
        linePaint,
      );
      canvas.drawLine(
        Offset(0, h * frac),
        Offset(w, h * frac),
        linePaint,
      );
    }

    // ── Centre vertical guide ────────────────────────────────────────────────
    _drawDashedLine(
      canvas,
      Offset(w * 0.5, h * 0.04),
      Offset(w * 0.5, h * 0.96),
      accentPaint,
    );

    // ── Hip-height horizontal guide ──────────────────────────────────────────
    _drawDashedLine(
      canvas,
      Offset(w * 0.15, h * 0.62),
      Offset(w * 0.85, h * 0.62),
      accentPaint,
    );

    // ── Stick-figure body silhouette ─────────────────────────────────────────
    _drawSilhouette(canvas, size, accentPaint);

    // ── Corner labels ────────────────────────────────────────────────────────
    _drawLabel(
      canvas,
      angle == SwingAngle.faceOn ? 'FACE-ON VIEW' : 'DOWN-THE-LINE VIEW',
      Offset(w / 2, h * 0.04),
      const Color(0xFF4CAF50),
      13,
    );

    _drawLabel(
      canvas,
      'Hip level',
      Offset(w * 0.87, h * 0.60),
      Colors.white.withOpacity(0.6),
      10,
    );

    _drawLabel(
      canvas,
      angle == SwingAngle.faceOn
          ? 'Face camera  •  full body visible'
          : 'Side-on to camera  •  target to your left',
      Offset(w / 2, h * 0.93),
      Colors.white.withOpacity(0.7),
      11,
    );
  }

  void _drawSilhouette(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;

    final cx = w * 0.5; // centre x

    // Head
    final headR = w * 0.048;
    final headCy = h * 0.18;
    canvas.drawCircle(Offset(cx, headCy), headR, paint);

    // Neck + shoulders
    final neckBottom = Offset(cx, headCy + headR + h * 0.02);
    final lShoulder = Offset(cx - w * 0.10, headCy + headR + h * 0.05);
    final rShoulder = Offset(cx + w * 0.10, headCy + headR + h * 0.05);
    canvas.drawLine(neckBottom, lShoulder, paint);
    canvas.drawLine(neckBottom, rShoulder, paint);

    // Arms (hanging at address)
    final lElbow = Offset(lShoulder.dx - w * 0.04, lShoulder.dy + h * 0.10);
    final rElbow = Offset(rShoulder.dx + w * 0.04, rShoulder.dy + h * 0.10);
    final lWrist = Offset(lElbow.dx - w * 0.02, lElbow.dy + h * 0.08);
    final rWrist = Offset(rElbow.dx + w * 0.02, rElbow.dy + h * 0.08);
    canvas.drawLine(lShoulder, lElbow, paint);
    canvas.drawLine(lElbow, lWrist, paint);
    canvas.drawLine(rShoulder, rElbow, paint);
    canvas.drawLine(rElbow, rWrist, paint);

    // Torso
    final hipMid = Offset(cx, h * 0.60);
    canvas.drawLine(neckBottom, hipMid, paint);

    // Legs
    final lHip = Offset(cx - w * 0.06, hipMid.dy);
    final rHip = Offset(cx + w * 0.06, hipMid.dy);
    final lKnee = Offset(lHip.dx, hipMid.dy + h * 0.12);
    final rKnee = Offset(rHip.dx, hipMid.dy + h * 0.12);
    final lAnkle = Offset(lHip.dx, hipMid.dy + h * 0.23);
    final rAnkle = Offset(rHip.dx, hipMid.dy + h * 0.23);
    canvas.drawLine(lHip, lKnee, paint);
    canvas.drawLine(lKnee, lAnkle, paint);
    canvas.drawLine(rHip, rKnee, paint);
    canvas.drawLine(rKnee, rAnkle, paint);

    // Feet
    canvas.drawLine(lAnkle, Offset(lAnkle.dx - w * 0.06, lAnkle.dy), paint);
    canvas.drawLine(rAnkle, Offset(rAnkle.dx + w * 0.06, rAnkle.dy), paint);

    // Club (simple line downward from wrists)
    final clubTop = Offset((lWrist.dx + rWrist.dx) / 2, (lWrist.dy + rWrist.dy) / 2);
    final clubHead = Offset(clubTop.dx + w * 0.12, hipMid.dy + h * 0.26);
    canvas.drawLine(clubTop, clubHead, paint);
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashLen = 10.0;
    const gapLen = 6.0;
    final total = math.sqrt(math.pow(b.dx - a.dx, 2) + math.pow(b.dy - a.dy, 2));
    if (total == 0) return;
    final dx = (b.dx - a.dx) / total;
    final dy = (b.dy - a.dy) / total;
    double pos = 0;
    bool drawing = true;
    while (pos < total) {
      final len = drawing ? dashLen : gapLen;
      final end = math.min(pos + len, total);
      if (drawing) {
        canvas.drawLine(
          Offset(a.dx + dx * pos, a.dy + dy * pos),
          Offset(a.dx + dx * end, a.dy + dy * end),
          paint,
        );
      }
      pos = end;
      drawing = !drawing;
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset center, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(CameraGuidePainter old) => old.angle != angle;
}
