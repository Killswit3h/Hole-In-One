import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/swing_analysis_result.dart';

/// Draws camera alignment guides on the live camera preview.
/// Proportioned to avoid overlapping the AppBar (~15% top) or record button (~25% bottom).
class CameraGuidePainter extends CustomPainter {
  final SwingAngle angle;

  const CameraGuidePainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final guidePaint = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.55)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final silhouettePaint = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.45)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // ── Thirds grid ───────────────────────────────────────────────────────────
    for (final f in [1 / 3, 2 / 3]) {
      canvas.drawLine(Offset(w * f, 0), Offset(w * f, h), gridPaint);
      canvas.drawLine(Offset(0, h * f), Offset(w, h * f), gridPaint);
    }

    // ── Vertical centre line (dashed) ─────────────────────────────────────────
    _dash(canvas, Offset(w * 0.5, h * 0.14), Offset(w * 0.5, h * 0.78), guidePaint);

    // ── Hip-level horizontal line (dashed) ────────────────────────────────────
    // Positioned at h*0.50 to align with the silhouette's hip joint
    _dash(canvas, Offset(w * 0.12, h * 0.50), Offset(w * 0.88, h * 0.50), guidePaint);

    // "Hip level" label
    _text(canvas, 'Hip level', Offset(w * 0.89, h * 0.49),
        Colors.white.withOpacity(0.55), 10, align: TextAlign.left);

    // ── Body silhouette (address position) ────────────────────────────────────
    _drawSilhouette(canvas, w, h, silhouettePaint);
  }

  /// Draws a golf-address stick-figure.
  /// Vertically bounded: top at h*0.16, ankles at h*0.72 — clear of both overlays.
  void _drawSilhouette(Canvas canvas, double w, double h, Paint p) {
    final cx = w * 0.5;

    // Head
    final headR = w * 0.046;
    final headCy = h * 0.21;
    canvas.drawCircle(Offset(cx, headCy), headR, p);

    // Neck down to shoulder mid
    final neckTop = Offset(cx, headCy + headR);
    final neckBot = Offset(cx, headCy + headR + h * 0.025);

    // Shoulders
    final lS = Offset(cx - w * 0.105, neckBot.dy + h * 0.025);
    final rS = Offset(cx + w * 0.105, neckBot.dy + h * 0.025);
    canvas.drawLine(neckBot, lS, p);
    canvas.drawLine(neckBot, rS, p);

    // Arms — angled inward toward club grip at address
    final lE = Offset(cx - w * 0.065, lS.dy + h * 0.095);
    final rE = Offset(cx + w * 0.065, rS.dy + h * 0.095);
    final lW = Offset(cx - w * 0.02, lE.dy + h * 0.075);
    final rW = Offset(cx + w * 0.02, rE.dy + h * 0.075);
    canvas.drawLine(lS, lE, p);
    canvas.drawLine(lE, lW, p);
    canvas.drawLine(rS, rE, p);
    canvas.drawLine(rE, rW, p);

    // Torso — slight forward lean
    final hipMid = Offset(cx + w * 0.012, h * 0.50);
    canvas.drawLine(neckBot, hipMid, p);

    // Hips
    final lH = Offset(hipMid.dx - w * 0.065, hipMid.dy);
    final rH = Offset(hipMid.dx + w * 0.065, hipMid.dy);

    // Legs — slight knee flex at address
    final lK = Offset(lH.dx - w * 0.01, lH.dy + h * 0.115);
    final rK = Offset(rH.dx + w * 0.01, rH.dy + h * 0.115);
    final lA = Offset(lH.dx - w * 0.008, lH.dy + h * 0.215);
    final rA = Offset(rH.dx + w * 0.008, rH.dy + h * 0.215);
    canvas.drawLine(lH, lK, p);
    canvas.drawLine(lK, lA, p);
    canvas.drawLine(rH, rK, p);
    canvas.drawLine(rK, rA, p);

    // Feet
    canvas.drawLine(lA, Offset(lA.dx - w * 0.055, lA.dy), p);
    canvas.drawLine(rA, Offset(rA.dx + w * 0.055, rA.dy), p);
  }

  void _dash(Canvas canvas, Offset a, Offset b, Paint paint,
      {double dashLen = 10, double gapLen = 6}) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final total = math.sqrt(dx * dx + dy * dy);
    if (total == 0) return;
    final nx = dx / total, ny = dy / total;
    double pos = 0;
    bool draw = true;
    while (pos < total) {
      final segEnd = math.min(pos + (draw ? dashLen : gapLen), total);
      if (draw) {
        canvas.drawLine(
          Offset(a.dx + nx * pos, a.dy + ny * pos),
          Offset(a.dx + nx * segEnd, a.dy + ny * segEnd),
          paint,
        );
      }
      pos = segEnd;
      draw = !draw;
    }
  }

  void _text(Canvas canvas, String text, Offset anchor, Color color,
      double fontSize,
      {TextAlign align = TextAlign.center}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          shadows: const [Shadow(color: Colors.black87, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout();
    tp.paint(canvas, Offset(anchor.dx, anchor.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(CameraGuidePainter old) => old.angle != angle;
}
