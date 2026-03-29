import 'dart:math' as math;

import '../models/pose_frame.dart';
import '../models/swing_analysis_result.dart';

export '../models/swing_analysis_result.dart' show SwingFault, FaultType;

enum SwingPhase { setup, backswing, top, downswing, impact, finish }

class SwingAngles {
  final double shoulderRotation;
  final double hipRotation;
  final double leftElbowBend;
  final double rightElbowBend;

  const SwingAngles({
    required this.shoulderRotation,
    required this.hipRotation,
    required this.leftElbowBend,
    required this.rightElbowBend,
  });
}

class PoseAnalysisService {
  static const _lShoulder = 'leftShoulder';
  static const _rShoulder = 'rightShoulder';
  static const _lHip = 'leftHip';
  static const _rHip = 'rightHip';
  static const _lElbow = 'leftElbow';
  static const _rElbow = 'rightElbow';
  static const _lWrist = 'leftWrist';
  static const _rWrist = 'rightWrist';
  static const _lKnee = 'leftKnee';
  static const _rKnee = 'rightKnee';
  static const _lAnkle = 'leftAnkle';
  static const _rAnkle = 'rightAnkle';
  static const _nose = 'nose';

  // ─── PHASE DETECTION ───────────────────────────────────────────────────────

  static Map<int, SwingPhase> detectSwingPhases(List<PoseFrame> frames) {
    if (frames.isEmpty) return {};

    final raw = List<SwingPhase>.filled(frames.length, SwingPhase.setup);
    var state = SwingPhase.setup;
    double? prevWristY;
    double? peakWristY;

    for (int i = 0; i < frames.length; i++) {
      final frame = frames[i];
      final wrist = frame.getLandmark(_rWrist) ??
          frame.getLandmark(_lWrist, minLikelihood: 0.3);
      final lS = frame.getLandmark(_lShoulder);
      final rS = frame.getLandmark(_rShoulder);
      final lH = frame.getLandmark(_lHip);
      final rH = frame.getLandmark(_rHip);

      if (wrist == null || lS == null || rS == null) {
        raw[i] = state;
        continue;
      }

      final wristY = wrist.y;
      final shoulderY = (lS.y + rS.y) / 2;
      final hipY = (lH != null && rH != null)
          ? (lH.y + rH.y) / 2
          : shoulderY + 0.2;

      switch (state) {
        case SwingPhase.setup:
          if (wristY < shoulderY - 0.04) state = SwingPhase.backswing;
          break;

        case SwingPhase.backswing:
          // Track peak
          if (prevWristY != null && wristY < prevWristY) {
            peakWristY = wristY;
          }
          // Wrist starts descending after peak → top then downswing
          if (prevWristY != null &&
              wristY > prevWristY + 0.02 &&
              peakWristY != null) {
            state = SwingPhase.top;
          }
          break;

        case SwingPhase.top:
          // Small pause at top, then downswing
          if (prevWristY != null && wristY > prevWristY + 0.03) {
            state = SwingPhase.downswing;
          }
          break;

        case SwingPhase.downswing:
          // Impact when wrist reaches hip level
          if (wristY > hipY - 0.05) state = SwingPhase.impact;
          break;

        case SwingPhase.impact:
          // Finish when wrist rises again above shoulders on follow-through
          if (wristY < shoulderY - 0.04 &&
              prevWristY != null &&
              wristY < prevWristY) {
            state = SwingPhase.finish;
          }
          break;

        case SwingPhase.finish:
          break;
      }

      raw[i] = state;
      prevWristY = wristY;
    }

    return _smoothPhases(raw);
  }

  static Map<int, SwingPhase> _smoothPhases(List<SwingPhase> raw) {
    const w = 5;
    final result = <int, SwingPhase>{};
    for (int i = 0; i < raw.length; i++) {
      final start = math.max(0, i - w ~/ 2);
      final end = math.min(raw.length - 1, i + w ~/ 2);
      final window = raw.sublist(start, end + 1);
      result[i] = _majority(window);
    }
    return result;
  }

  static SwingPhase _majority(List<SwingPhase> phases) {
    final counts = <SwingPhase, int>{};
    for (final p in phases) counts[p] = (counts[p] ?? 0) + 1;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  // ─── KEY FRAME FINDERS ─────────────────────────────────────────────────────

  static int? findSetupFrameIdx(List<PoseFrame> frames, Map<int, SwingPhase> phases) {
    // First frame labeled as setup with good landmark confidence
    for (final e in phases.entries) {
      if (e.value == SwingPhase.setup) {
        final f = frames[e.key];
        if (f.getLandmark(_lShoulder, minLikelihood: 0.5) != null) return e.key;
      }
    }
    return null;
  }

  static int? findBackswingPeakIdx(List<PoseFrame> frames, Map<int, SwingPhase> phases) {
    double minY = double.infinity;
    int? idx;
    for (final e in phases.entries) {
      if (e.value != SwingPhase.backswing && e.value != SwingPhase.top) continue;
      final wrist = frames[e.key].getLandmark(_rWrist) ??
          frames[e.key].getLandmark(_lWrist, minLikelihood: 0.3);
      if (wrist != null && wrist.y < minY) {
        minY = wrist.y;
        idx = e.key;
      }
    }
    return idx;
  }

  static int? findImpactIdx(List<PoseFrame> frames, Map<int, SwingPhase> phases) {
    final impacts = phases.entries.where((e) => e.value == SwingPhase.impact).toList();
    if (impacts.isEmpty) return null;
    return impacts.first.key;
  }

  static int? findFinishIdx(List<PoseFrame> frames, Map<int, SwingPhase> phases) {
    final finishes = phases.entries.where((e) => e.value == SwingPhase.finish).toList();
    if (finishes.isEmpty) return null;
    return finishes.last.key;
  }

  // ─── FULL SWING ANALYSIS ───────────────────────────────────────────────────

  static SwingAnalysisResult analyzeSwing(
    List<PoseFrame> frames,
    Map<int, SwingPhase> phases,
  ) {
    if (frames.isEmpty) return _emptyResult();

    final setupIdx = findSetupFrameIdx(frames, phases);
    final peakIdx = findBackswingPeakIdx(frames, phases);
    final impactIdx = findImpactIdx(frames, phases);
    final finishIdx = findFinishIdx(frames, phases);

    final setupFrame = setupIdx != null ? frames[setupIdx] : null;
    final peakFrame = peakIdx != null ? frames[peakIdx] : null;
    final impactFrame = impactIdx != null ? frames[impactIdx] : null;

    // Tempo
    int backswingMs = 0;
    int downswingMs = 0;
    double tempoRatio = 0;
    if (setupIdx != null && peakIdx != null && impactIdx != null) {
      backswingMs = frames[peakIdx].timestampMs - frames[setupIdx].timestampMs;
      downswingMs = frames[impactIdx].timestampMs - frames[peakIdx].timestampMs;
      if (downswingMs > 0) tempoRatio = backswingMs / downswingMs;
    }

    // Detect all faults
    final faults = <SwingFault>[
      _detectStanceWidth(setupFrame),
      _detectShoulderTurn(peakFrame),
      _detectTempo(tempoRatio),
      _detectSway(setupFrame, peakFrame),
      _detectHipRotation(impactFrame),
      _detectHeadMovement(setupFrame, impactFrame),
      _detectFlyingElbow(peakFrame),
      _detectBentLeadArm(peakFrame),
      _detectLossOfPosture(setupFrame, impactFrame),
      _detectEarlyExtension(setupFrame, impactFrame),
    ];

    // Top priority = detected fault with highest severity
    final detected = faults.where((f) => f.detected).toList()
      ..sort((a, b) => b.severity.compareTo(a.severity));
    final topFault = detected.isNotEmpty ? detected.first : null;

    // Score
    final score = _computeScore(faults);

    // Strengths
    final tempoOk = tempoRatio >= 2.0 && tempoRatio <= 4.5;
    final headFault = faults.firstWhere((f) => f.type == FaultType.headMovement);
    final swayFault = faults.firstWhere((f) => f.type == FaultType.sway);
    final stabilityOk = !headFault.detected && !swayFault.detected;
    final hipFault = faults.firstWhere((f) => f.type == FaultType.hipRotation);
    final earlyFault = faults.firstWhere((f) => f.type == FaultType.earlyExtension);
    final impactOk = !hipFault.detected && !earlyFault.detected;

    // Tips
    final tips = _buildTips(faults, topFault);

    return SwingAnalysisResult(
      score: score,
      tempoStrength: tempoOk,
      stabilityStrength: stabilityOk,
      impactStrength: impactOk,
      faults: faults,
      topPriorityFault: topFault,
      tempoRatio: tempoRatio,
      backswingMs: backswingMs,
      downswingMs: downswingMs,
      setupFrameIdx: setupIdx,
      backswingPeakIdx: peakIdx,
      impactFrameIdx: impactIdx,
      finishFrameIdx: finishIdx,
      tips: tips,
    );
  }

  // ─── FAULT DETECTORS ───────────────────────────────────────────────────────

  static SwingFault _detectStanceWidth(PoseFrame? setup) {
    const name = 'Stance Width';
    const desc = 'Narrow stance reduces stability and balance during the swing.';
    const fix = 'Set up with feet shoulder-width apart for a solid, balanced base.';

    if (setup == null) return _passFault(FaultType.stanceWidth, name, desc, fix);

    final lA = setup.getLandmark(_lAnkle, minLikelihood: 0.4);
    final rA = setup.getLandmark(_rAnkle, minLikelihood: 0.4);
    if (lA == null || rA == null) return _passFault(FaultType.stanceWidth, name, desc, fix);

    final width = (lA.x - rA.x).abs();
    if (width < 0.10) {
      // Too narrow
      return SwingFault(
        type: FaultType.stanceWidth,
        name: name,
        description: 'Your stance is too narrow — this limits your turn and balance.',
        fix: fix,
        detected: true,
        severity: ((0.10 - width) / 0.10).clamp(0.0, 1.0),
        faultedLandmarks: [_lAnkle, _rAnkle],
      );
    }
    if (width > 0.40) {
      // Too wide
      return SwingFault(
        type: FaultType.stanceWidth,
        name: name,
        description: 'Your stance is too wide — this restricts your hip turn and weight transfer.',
        fix: 'Narrow your stance to shoulder-width for better rotation.',
        detected: true,
        severity: ((width - 0.40) / 0.20).clamp(0.0, 1.0),
        faultedLandmarks: [_lAnkle, _rAnkle],
      );
    }
    return _passFault(FaultType.stanceWidth, name, desc, fix);
  }

  static SwingFault _detectShoulderTurn(PoseFrame? peak) {
    const name = 'Shoulder Turn';
    const desc = 'Insufficient shoulder rotation reduces power and swing arc.';
    const fix = 'Rotate your lead shoulder under your chin at the top of the backswing.';

    if (peak == null) return _passFault(FaultType.shoulderTurn, name, desc, fix);

    final lS = peak.getLandmark(_lShoulder, minLikelihood: 0.4);
    final rS = peak.getLandmark(_rShoulder, minLikelihood: 0.4);
    if (lS == null || rS == null) return _passFault(FaultType.shoulderTurn, name, desc, fix);

    // Shoulder line tilt vs horizontal (degrees)
    final angle = (math.atan2((lS.y - rS.y).abs(), (lS.x - rS.x).abs()) *
            (180 / math.pi))
        .abs();

    if (angle < 8.0) {
      return SwingFault(
        type: FaultType.shoulderTurn,
        name: name,
        description: 'You\'re not rotating your shoulders enough — this limits your backswing and power.',
        fix: fix,
        detected: true,
        severity: ((8.0 - angle) / 8.0).clamp(0.0, 1.0),
        faultedLandmarks: [_lShoulder, _rShoulder],
      );
    }
    return _passFault(FaultType.shoulderTurn, name, desc, fix);
  }

  static SwingFault _detectTempo(double ratio) {
    const name = 'Swing Tempo';
    const desc = 'Good tempo (3:1 backswing to downswing) creates effortless power.';
    const fix = 'Slow your takeaway — feel a smooth, unhurried backswing before accelerating through impact.';

    if (ratio <= 0) return _passFault(FaultType.tempo, name, desc, fix);

    if (ratio < 1.5) {
      return SwingFault(
        type: FaultType.tempo,
        name: name,
        description: 'Your backswing is too fast relative to your downswing — you\'re rushing the takeaway.',
        fix: fix,
        detected: true,
        severity: ((1.5 - ratio) / 1.5).clamp(0.0, 1.0),
        faultedLandmarks: [],
      );
    }
    if (ratio > 5.0) {
      return SwingFault(
        type: FaultType.tempo,
        name: name,
        description: 'Your backswing is too slow — you may be losing rhythm and momentum.',
        fix: 'Maintain a smooth, continuous motion — avoid pausing too long at the top.',
        detected: true,
        severity: ((ratio - 5.0) / 3.0).clamp(0.0, 1.0),
        faultedLandmarks: [],
      );
    }
    return _passFault(FaultType.tempo, name, desc, fix);
  }

  static SwingFault _detectSway(PoseFrame? setup, PoseFrame? peak) {
    const name = 'Hip Sway';
    const desc = 'Lateral hip movement in the backswing causes inconsistent contact.';
    const fix = 'Keep your trail hip over your trail knee — feel like you\'re turning in a barrel.';

    if (setup == null || peak == null) return _passFault(FaultType.sway, name, desc, fix);

    final sLH = setup.getLandmark(_lHip, minLikelihood: 0.4);
    final sRH = setup.getLandmark(_rHip, minLikelihood: 0.4);
    final pLH = peak.getLandmark(_lHip, minLikelihood: 0.4);
    final pRH = peak.getLandmark(_rHip, minLikelihood: 0.4);
    if (sLH == null || sRH == null || pLH == null || pRH == null) {
      return _passFault(FaultType.sway, name, desc, fix);
    }

    final setupHipX = (sLH.x + sRH.x) / 2;
    final peakHipX = (pLH.x + pRH.x) / 2;
    final lateral = (peakHipX - setupHipX).abs();

    if (lateral > 0.07) {
      return SwingFault(
        type: FaultType.sway,
        name: name,
        description: 'Your hips are sliding laterally in the backswing instead of rotating.',
        fix: fix,
        detected: true,
        severity: ((lateral - 0.07) / 0.10).clamp(0.0, 1.0),
        faultedLandmarks: [_lHip, _rHip],
      );
    }
    return _passFault(FaultType.sway, name, desc, fix);
  }

  static SwingFault _detectHipRotation(PoseFrame? impact) {
    const name = 'Hip Rotation';
    const desc = 'Clearing the hips at impact generates power and prevents a slice.';
    const fix = 'Initiate the downswing by rotating your hips toward the target before your arms come down.';

    if (impact == null) return _passFault(FaultType.hipRotation, name, desc, fix);

    final lH = impact.getLandmark(_lHip, minLikelihood: 0.4);
    final rH = impact.getLandmark(_rHip, minLikelihood: 0.4);
    if (lH == null || rH == null) return _passFault(FaultType.hipRotation, name, desc, fix);

    final angle = (math.atan2((lH.y - rH.y).abs(), (lH.x - rH.x).abs()) *
            (180 / math.pi))
        .abs();

    if (angle < 10.0) {
      return SwingFault(
        type: FaultType.hipRotation,
        name: name,
        description: 'Your hips are not clearing at impact — this blocks power and can cause a slice.',
        fix: fix,
        detected: true,
        severity: ((10.0 - angle) / 10.0).clamp(0.0, 1.0),
        faultedLandmarks: [_lHip, _rHip],
      );
    }
    return _passFault(FaultType.hipRotation, name, desc, fix);
  }

  static SwingFault _detectHeadMovement(PoseFrame? setup, PoseFrame? impact) {
    const name = 'Head Movement';
    const desc = 'Excessive head movement causes loss of posture and inconsistent contact.';
    const fix = 'Keep your head relatively still — your eyes should stay focused on the ball through impact.';

    if (setup == null || impact == null) return _passFault(FaultType.headMovement, name, desc, fix);

    final sNose = setup.getLandmark(_nose, minLikelihood: 0.4);
    final iNose = impact.getLandmark(_nose, minLikelihood: 0.4);
    if (sNose == null || iNose == null) return _passFault(FaultType.headMovement, name, desc, fix);

    final lateral = (iNose.x - sNose.x).abs();
    final vertical = (iNose.y - sNose.y).abs();
    final movement = math.sqrt(lateral * lateral + vertical * vertical);

    if (movement > 0.08) {
      return SwingFault(
        type: FaultType.headMovement,
        name: name,
        description: 'Your head is moving too much during the swing — this throws off your swing plane.',
        fix: fix,
        detected: true,
        severity: ((movement - 0.08) / 0.12).clamp(0.0, 1.0),
        faultedLandmarks: [_nose],
      );
    }
    return _passFault(FaultType.headMovement, name, desc, fix);
  }

  static SwingFault _detectFlyingElbow(PoseFrame? peak) {
    const name = 'Flying Trail Elbow';
    const desc = 'A flying trail elbow flattens the swing plane and reduces consistency.';
    const fix = 'Keep your trail elbow pointed down at the ground at the top — think "elbow in a shirt pocket."';

    if (peak == null) return _passFault(FaultType.flyingElbow, name, desc, fix);

    final rS = peak.getLandmark(_rShoulder, minLikelihood: 0.4);
    final rE = peak.getLandmark(_rElbow, minLikelihood: 0.4);
    if (rS == null || rE == null) return _passFault(FaultType.flyingElbow, name, desc, fix);

    // In face-on, at the top of backswing the trail elbow should not be
    // significantly further from center than the trail shoulder.
    final separation = (rE.x - rS.x).abs();

    if (separation > 0.10) {
      return SwingFault(
        type: FaultType.flyingElbow,
        name: name,
        description: 'Your trail elbow is flying out away from your body at the top of the backswing.',
        fix: fix,
        detected: true,
        severity: ((separation - 0.10) / 0.10).clamp(0.0, 1.0),
        faultedLandmarks: [_rElbow, _rShoulder],
      );
    }
    return _passFault(FaultType.flyingElbow, name, desc, fix);
  }

  static SwingFault _detectBentLeadArm(PoseFrame? peak) {
    const name = 'Bent Lead Arm';
    const desc = 'A bent lead arm at the top shortens your arc and reduces power.';
    const fix = 'Keep your lead arm as straight as possible through the backswing for a wider, more powerful arc.';

    if (peak == null) return _passFault(FaultType.bentLeadArm, name, desc, fix);

    final lS = peak.getLandmark(_lShoulder, minLikelihood: 0.4);
    final lE = peak.getLandmark(_lElbow, minLikelihood: 0.4);
    final lW = peak.getLandmark(_lWrist, minLikelihood: 0.4);
    if (lS == null || lE == null || lW == null) {
      return _passFault(FaultType.bentLeadArm, name, desc, fix);
    }

    final angle = _threePointAngle(
      ax: lS.x, ay: lS.y,
      bx: lE.x, by: lE.y,
      cx: lW.x, cy: lW.y,
    );

    if (angle < 145) {
      return SwingFault(
        type: FaultType.bentLeadArm,
        name: name,
        description: 'Your lead arm is bent (${angle.toStringAsFixed(0)}°) at the top — aim for 160°+.',
        fix: fix,
        detected: true,
        severity: ((145.0 - angle) / 45.0).clamp(0.0, 1.0),
        faultedLandmarks: [_lShoulder, _lElbow, _lWrist],
      );
    }
    return _passFault(FaultType.bentLeadArm, name, desc, fix);
  }

  static SwingFault _detectLossOfPosture(PoseFrame? setup, PoseFrame? impact) {
    const name = 'Loss of Posture';
    const desc = 'Standing up through impact causes thin, topped, and off-centre shots.';
    const fix = 'Maintain your spine angle from setup through impact — feel like you stay "in the box."';

    if (setup == null || impact == null) return _passFault(FaultType.lossOfPosture, name, desc, fix);

    final sLS = setup.getLandmark(_lShoulder, minLikelihood: 0.4);
    final sLH = setup.getLandmark(_lHip, minLikelihood: 0.4);
    final iLS = impact.getLandmark(_lShoulder, minLikelihood: 0.4);
    final iLH = impact.getLandmark(_lHip, minLikelihood: 0.4);
    if (sLS == null || sLH == null || iLS == null || iLH == null) {
      return _passFault(FaultType.lossOfPosture, name, desc, fix);
    }

    // Spine length proxy (shoulder y to hip y distance) — if shorter at impact, golfer stood up
    final setupLength = (sLH.y - sLS.y).abs();
    final impactLength = (iLH.y - iLS.y).abs();
    final change = setupLength > 0 ? (setupLength - impactLength) / setupLength : 0.0;

    if (change > 0.15) {
      return SwingFault(
        type: FaultType.lossOfPosture,
        name: name,
        description: 'You\'re standing up and losing your spine angle through impact.',
        fix: fix,
        detected: true,
        severity: change.clamp(0.0, 1.0),
        faultedLandmarks: [_lShoulder, _lHip, _rShoulder, _rHip],
      );
    }
    return _passFault(FaultType.lossOfPosture, name, desc, fix);
  }

  static SwingFault _detectEarlyExtension(PoseFrame? setup, PoseFrame? impact) {
    const name = 'Early Extension';
    const desc = 'Thrusting the hips toward the ball forces your arms off-plane and causes thin and blocked shots.';
    const fix = 'Keep your trail glute on the wall — think "hips rotate, not thrust" through impact.';

    if (setup == null || impact == null) return _passFault(FaultType.earlyExtension, name, desc, fix);

    // In face-on: early extension shows as hips moving toward camera (x-axis)
    // Proxy: compare knee flexion via knee–hip–shoulder angle
    final sLK = setup.getLandmark(_lKnee, minLikelihood: 0.4);
    final sLH = setup.getLandmark(_lHip, minLikelihood: 0.4);
    final sLS = setup.getLandmark(_lShoulder, minLikelihood: 0.4);
    final iLK = impact.getLandmark(_lKnee, minLikelihood: 0.4);
    final iLH = impact.getLandmark(_lHip, minLikelihood: 0.4);
    final iLS = impact.getLandmark(_lShoulder, minLikelihood: 0.4);

    if (sLK == null || sLH == null || sLS == null ||
        iLK == null || iLH == null || iLS == null) {
      return _passFault(FaultType.earlyExtension, name, desc, fix);
    }

    final setupAngle = _threePointAngle(
      ax: sLK.x, ay: sLK.y,
      bx: sLH.x, by: sLH.y,
      cx: sLS.x, cy: sLS.y,
    );
    final impactAngle = _threePointAngle(
      ax: iLK.x, ay: iLK.y,
      bx: iLH.x, by: iLH.y,
      cx: iLS.x, cy: iLS.y,
    );

    // If the hip-knee-shoulder angle increases significantly → hips thrusting forward
    final change = impactAngle - setupAngle;
    if (change > 18) {
      return SwingFault(
        type: FaultType.earlyExtension,
        name: name,
        description: 'Your hips are thrusting toward the ball through impact (early extension).',
        fix: fix,
        detected: true,
        severity: ((change - 18) / 22).clamp(0.0, 1.0),
        faultedLandmarks: [_lHip, _rHip, _lKnee, _rKnee],
      );
    }
    return _passFault(FaultType.earlyExtension, name, desc, fix);
  }

  // ─── SCORING ───────────────────────────────────────────────────────────────

  static int _computeScore(List<SwingFault> faults) {
    // Weight per fault type (max deduction)
    const weights = <FaultType, double>{
      FaultType.tempo: 14,
      FaultType.lossOfPosture: 13,
      FaultType.earlyExtension: 13,
      FaultType.sway: 12,
      FaultType.hipRotation: 11,
      FaultType.headMovement: 10,
      FaultType.shoulderTurn: 9,
      FaultType.flyingElbow: 8,
      FaultType.bentLeadArm: 7,
      FaultType.stanceWidth: 6,
    };

    double deduction = 0;
    for (final f in faults) {
      if (!f.detected) continue;
      final maxDed = weights[f.type] ?? 8.0;
      deduction += maxDed * f.severity;
    }
    return (100 - deduction).clamp(0, 100).round();
  }

  // ─── TIPS ──────────────────────────────────────────────────────────────────

  static List<String> _buildTips(List<SwingFault> faults, SwingFault? topFault) {
    final tips = faults.where((f) => f.detected).map((f) => f.fix).toList();
    if (tips.isEmpty) {
      return ['Great swing! Keep recording regularly to track your progress over time.'];
    }
    return tips.take(3).toList();
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────────

  static SwingFault _passFault(
      FaultType type, String name, String desc, String fix) {
    return SwingFault(
      type: type,
      name: name,
      description: desc,
      fix: fix,
      detected: false,
    );
  }

  static double _threePointAngle({
    required double ax, required double ay,
    required double bx, required double by,
    required double cx, required double cy,
  }) {
    final bax = ax - bx, bay = ay - by;
    final bcx = cx - bx, bcy = cy - by;
    final dot = bax * bcx + bay * bcy;
    final mag = math.sqrt(bax * bax + bay * bay) *
        math.sqrt(bcx * bcx + bcy * bcy);
    if (mag == 0) return 180;
    return math.acos((dot / mag).clamp(-1.0, 1.0)) * (180 / math.pi);
  }

  // ─── LEGACY HELPERS (keep existing callers working) ────────────────────────

  static SwingAngles? calculateAngles(PoseFrame frame) {
    final lS = frame.getLandmark('leftShoulder', minLikelihood: 0.4);
    final rS = frame.getLandmark('rightShoulder', minLikelihood: 0.4);
    final lH = frame.getLandmark('leftHip', minLikelihood: 0.4);
    final rH = frame.getLandmark('rightHip', minLikelihood: 0.4);
    final lE = frame.getLandmark('leftElbow', minLikelihood: 0.4);
    final rE = frame.getLandmark('rightElbow', minLikelihood: 0.4);
    final lW = frame.getLandmark('leftWrist', minLikelihood: 0.4);
    final rW = frame.getLandmark('rightWrist', minLikelihood: 0.4);

    if (lS == null || rS == null) return null;

    final shoulderRot = math.atan2(rS.y - lS.y, rS.x - lS.x) * (180 / math.pi);
    double hipRot = 0;
    if (lH != null && rH != null) {
      hipRot = math.atan2(rH.y - lH.y, rH.x - lH.x) * (180 / math.pi);
    }
    double lEB = 180, rEB = 180;
    if (lE != null && lW != null) {
      lEB = _threePointAngle(ax: lS.x, ay: lS.y, bx: lE.x, by: lE.y, cx: lW.x, cy: lW.y);
    }
    if (rE != null && rW != null) {
      rEB = _threePointAngle(ax: rS.x, ay: rS.y, bx: rE.x, by: rE.y, cx: rW.x, cy: rW.y);
    }
    return SwingAngles(
      shoulderRotation: shoulderRot.abs(),
      hipRotation: hipRot.abs(),
      leftElbowBend: lEB,
      rightElbowBend: rEB,
    );
  }

  static PoseFrame? findNearestFrame(List<PoseFrame> frames, Duration position) {
    if (frames.isEmpty) return null;
    final target = position.inMilliseconds;
    int lo = 0, hi = frames.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      frames[mid].timestampMs < target ? lo = mid + 1 : hi = mid;
    }
    if (lo > 0) {
      final prev = (frames[lo - 1].timestampMs - target).abs();
      final curr = (frames[lo].timestampMs - target).abs();
      return prev < curr ? frames[lo - 1] : frames[lo];
    }
    return frames[lo];
  }

  static SwingPhase? phaseAtPosition(
    List<PoseFrame> frames,
    Map<int, SwingPhase> phases,
    Duration position,
  ) {
    if (frames.isEmpty || phases.isEmpty) return null;
    final target = position.inMilliseconds;
    int nearestIdx = 0, minDiff = (frames[0].timestampMs - target).abs();
    for (int i = 1; i < frames.length; i++) {
      final d = (frames[i].timestampMs - target).abs();
      if (d < minDiff) { minDiff = d; nearestIdx = i; }
    }
    return phases[nearestIdx];
  }

  static String phaseLabel(SwingPhase phase) {
    switch (phase) {
      case SwingPhase.setup: return 'Setup';
      case SwingPhase.backswing: return 'Backswing';
      case SwingPhase.top: return 'Top';
      case SwingPhase.downswing: return 'Downswing';
      case SwingPhase.impact: return 'Impact';
      case SwingPhase.finish: return 'Finish';
    }
  }

  static SwingAnalysisResult _emptyResult() => const SwingAnalysisResult(
    score: 0,
    tempoStrength: false,
    stabilityStrength: false,
    impactStrength: false,
    faults: [],
    topPriorityFault: null,
    tempoRatio: 0,
    backswingMs: 0,
    downswingMs: 0,
    tips: ['Record a full swing to receive your analysis.'],
  );
}
