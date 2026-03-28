import 'dart:math' as math;

import '../models/pose_frame.dart';

enum SwingPhase { setup, backswing, impact, followThrough }

class SwingAngles {
  final double shoulderRotation; // degrees, tilt of shoulder line vs horizontal
  final double hipRotation; // degrees, tilt of hip line vs horizontal
  final double leftElbowBend; // degrees (180 = straight)
  final double rightElbowBend; // degrees (180 = straight)

  const SwingAngles({
    required this.shoulderRotation,
    required this.hipRotation,
    required this.leftElbowBend,
    required this.rightElbowBend,
  });
}

class PoseAnalysisService {
  // Landmark type names matching google_mlkit_pose_detection PoseLandmarkType.name
  static const String _leftShoulder = 'leftShoulder';
  static const String _rightShoulder = 'rightShoulder';
  static const String _leftHip = 'leftHip';
  static const String _rightHip = 'rightHip';
  static const String _leftElbow = 'leftElbow';
  static const String _rightElbow = 'rightElbow';
  static const String _leftWrist = 'leftWrist';
  static const String _rightWrist = 'rightWrist';
  static const String _leftKnee = 'leftKnee';
  static const String _rightKnee = 'rightKnee';
  static const String _leftAnkle = 'leftAnkle';
  static const String _rightAnkle = 'rightAnkle';

  static const List<String> allLandmarkTypes = [
    _leftShoulder,
    _rightShoulder,
    _leftHip,
    _rightHip,
    _leftElbow,
    _rightElbow,
    _leftWrist,
    _rightWrist,
    _leftKnee,
    _rightKnee,
    _leftAnkle,
    _rightAnkle,
  ];

  /// Detects swing phase for each frame index using a state machine.
  /// Returns Map<frameIndex, SwingPhase>.
  static Map<int, SwingPhase> detectSwingPhases(List<PoseFrame> frames) {
    if (frames.isEmpty) return {};

    final rawPhases = List<SwingPhase>.filled(frames.length, SwingPhase.setup);
    var state = SwingPhase.setup;

    // Track previous wrist Y for derivative
    double? prevWristY;

    for (int i = 0; i < frames.length; i++) {
      final frame = frames[i];
      final wrist = frame.getLandmark(_rightWrist) ??
          frame.getLandmark(_leftWrist, minLikelihood: 0.3);
      final lShoulder = frame.getLandmark(_leftShoulder);
      final rShoulder = frame.getLandmark(_rightShoulder);
      final lHip = frame.getLandmark(_leftHip);
      final rHip = frame.getLandmark(_rightHip);

      if (wrist == null || lShoulder == null || rShoulder == null) {
        rawPhases[i] = state;
        continue;
      }

      final wristY = wrist.y;
      final shoulderY = (lShoulder.y + rShoulder.y) / 2;
      final hipY = (lHip != null && rHip != null)
          ? (lHip.y + rHip.y) / 2
          : shoulderY + 0.2;

      // State machine transitions (Y coords: 0=top, 1=bottom of image)
      switch (state) {
        case SwingPhase.setup:
          // Transition to backswing when wrist rises significantly above shoulders
          if (wristY < shoulderY - 0.05) {
            state = SwingPhase.backswing;
          }
          break;

        case SwingPhase.backswing:
          // Transition to impact when wrist starts descending back toward hip level
          // Detect local maximum (wrist was going up, now going down)
          if (prevWristY != null && wristY > prevWristY + 0.03) {
            state = SwingPhase.impact;
          }
          break;

        case SwingPhase.impact:
          // Transition to follow-through when wrist rises again above shoulders
          if (wristY < shoulderY - 0.05 && prevWristY != null && wristY < prevWristY) {
            state = SwingPhase.followThrough;
          }
          // Also transition if wrist drops below hips (impact zone passed)
          if (wristY > hipY + 0.05 && prevWristY != null && wristY < prevWristY) {
            state = SwingPhase.followThrough;
          }
          break;

        case SwingPhase.followThrough:
          break;
      }

      rawPhases[i] = state;
      prevWristY = wristY;
    }

    // Smooth with 5-frame sliding window (majority vote)
    return _smoothPhases(rawPhases);
  }

  static Map<int, SwingPhase> _smoothPhases(List<SwingPhase> raw) {
    const windowSize = 5;
    final result = <int, SwingPhase>{};
    for (int i = 0; i < raw.length; i++) {
      final start = math.max(0, i - windowSize ~/ 2);
      final end = math.min(raw.length - 1, i + windowSize ~/ 2);
      final window = raw.sublist(start, end + 1);
      result[i] = _majority(window);
    }
    return result;
  }

  static SwingPhase _majority(List<SwingPhase> phases) {
    final counts = <SwingPhase, int>{};
    for (final p in phases) {
      counts[p] = (counts[p] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Calculates joint angles for a single pose frame.
  static SwingAngles? calculateAngles(PoseFrame frame) {
    final lShoulder = frame.getLandmark(_leftShoulder, minLikelihood: 0.4);
    final rShoulder = frame.getLandmark(_rightShoulder, minLikelihood: 0.4);
    final lHip = frame.getLandmark(_leftHip, minLikelihood: 0.4);
    final rHip = frame.getLandmark(_rightHip, minLikelihood: 0.4);
    final lElbow = frame.getLandmark(_leftElbow, minLikelihood: 0.4);
    final rElbow = frame.getLandmark(_rightElbow, minLikelihood: 0.4);
    final lWrist = frame.getLandmark(_leftWrist, minLikelihood: 0.4);
    final rWrist = frame.getLandmark(_rightWrist, minLikelihood: 0.4);

    if (lShoulder == null || rShoulder == null) return null;

    // Shoulder rotation: angle of line between shoulders vs horizontal
    final shoulderRotation = math.atan2(
          rShoulder.y - lShoulder.y,
          rShoulder.x - lShoulder.x,
        ) *
        (180 / math.pi);

    // Hip rotation
    double hipRotation = 0;
    if (lHip != null && rHip != null) {
      hipRotation = math.atan2(
            rHip.y - lHip.y,
            rHip.x - lHip.x,
          ) *
          (180 / math.pi);
    }

    // Left elbow bend (shoulder → elbow → wrist)
    double leftElbowBend = 180;
    if (lElbow != null && lWrist != null) {
      leftElbowBend = _threePointAngle(
        ax: lShoulder.x, ay: lShoulder.y,
        bx: lElbow.x, by: lElbow.y,
        cx: lWrist.x, cy: lWrist.y,
      );
    }

    // Right elbow bend
    double rightElbowBend = 180;
    if (rElbow != null && rWrist != null) {
      rightElbowBend = _threePointAngle(
        ax: rShoulder.x, ay: rShoulder.y,
        bx: rElbow.x, by: rElbow.y,
        cx: rWrist.x, cy: rWrist.y,
      );
    }

    return SwingAngles(
      shoulderRotation: shoulderRotation.abs(),
      hipRotation: hipRotation.abs(),
      leftElbowBend: leftElbowBend,
      rightElbowBend: rightElbowBend,
    );
  }

  /// Angle at point B formed by vectors BA and BC (in degrees).
  static double _threePointAngle({
    required double ax, required double ay,
    required double bx, required double by,
    required double cx, required double cy,
  }) {
    final bax = ax - bx;
    final bay = ay - by;
    final bcx = cx - bx;
    final bcy = cy - by;

    final dot = bax * bcx + bay * bcy;
    final magBA = math.sqrt(bax * bax + bay * bay);
    final magBC = math.sqrt(bcx * bcx + bcy * bcy);

    if (magBA == 0 || magBC == 0) return 180;

    final cosAngle = (dot / (magBA * magBC)).clamp(-1.0, 1.0);
    return math.acos(cosAngle) * (180 / math.pi);
  }

  /// Finds the frame index of the backswing peak (wrist highest position).
  static int? findBackswingPeakIndex(
      List<PoseFrame> frames, Map<int, SwingPhase> phases) {
    double minWristY = double.infinity;
    int? peakIdx;

    for (final entry in phases.entries) {
      if (entry.value != SwingPhase.backswing) continue;
      final frame = frames[entry.key];
      final wrist = frame.getLandmark(_rightWrist) ??
          frame.getLandmark(_leftWrist, minLikelihood: 0.3);
      if (wrist != null && wrist.y < minWristY) {
        minWristY = wrist.y;
        peakIdx = entry.key;
      }
    }
    return peakIdx;
  }

  /// Finds the frame index closest to impact.
  static int? findImpactIndex(
      List<PoseFrame> frames, Map<int, SwingPhase> phases) {
    final impactFrames =
        phases.entries.where((e) => e.value == SwingPhase.impact).toList();
    if (impactFrames.isEmpty) return null;
    // Return the first impact frame
    return impactFrames.first.key;
  }

  /// Generates up to 3 coaching tips based on detected poses and phases.
  static List<String> generateTips(
      List<PoseFrame> frames, Map<int, SwingPhase> phases) {
    if (frames.isEmpty) return [_defaultTip()];

    final tips = <_ScoredTip>[];

    final backswingIdx = findBackswingPeakIndex(frames, phases);
    if (backswingIdx != null) {
      final angles = calculateAngles(frames[backswingIdx]);
      if (angles != null) {
        if (angles.shoulderRotation < 30) {
          tips.add(_ScoredTip(
            'Rotate your shoulders more fully during the backswing — aim for 45°+ of tilt for maximum power.',
            score: 3,
          ));
        }
        if (angles.hipRotation > 25) {
          tips.add(_ScoredTip(
            'Restrict your hip turn during the backswing to build more torque between your upper and lower body.',
            score: 2,
          ));
        }
        if (angles.rightElbowBend < 80) {
          tips.add(_ScoredTip(
            'Keep your trail elbow closer to your body on the backswing — a "flying elbow" reduces control.',
            score: 2,
          ));
        }
        if (angles.leftElbowBend < 150) {
          tips.add(_ScoredTip(
            'Try to keep your lead arm straighter during the backswing for a wider arc and more distance.',
            score: 1,
          ));
        }
      }
    }

    final impactIdx = findImpactIndex(frames, phases);
    if (impactIdx != null) {
      final angles = calculateAngles(frames[impactIdx]);
      if (angles != null) {
        if (angles.leftElbowBend < 150) {
          tips.add(_ScoredTip(
            'Keep your lead arm straighter at impact — a bent lead arm leads to inconsistent contact.',
            score: 3,
          ));
        }
        if (angles.shoulderRotation < 10) {
          tips.add(_ScoredTip(
            'Drive your shoulder rotation through impact — clearing the shoulders generates power and prevents a slice.',
            score: 3,
          ));
        }
        if (angles.hipRotation < 20) {
          tips.add(_ScoredTip(
            'Rotate your hips more aggressively through impact to transfer power from your lower body.',
            score: 2,
          ));
        }
      }
    }

    if (tips.isEmpty) return [_defaultTip()];

    // Sort by score descending, take top 3
    tips.sort((a, b) => b.score.compareTo(a.score));
    return tips.take(3).map((t) => t.text).toList();
  }

  static String _defaultTip() =>
      'Complete a full swing to receive personalized coaching tips based on your joint angles and swing phases.';

  /// Binary search for the pose frame nearest to [position].
  static PoseFrame? findNearestFrame(
      List<PoseFrame> frames, Duration position) {
    if (frames.isEmpty) return null;
    final targetMs = position.inMilliseconds;

    int lo = 0, hi = frames.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (frames[mid].timestampMs < targetMs) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }

    if (lo > 0) {
      final prevDiff = (frames[lo - 1].timestampMs - targetMs).abs();
      final currDiff = (frames[lo].timestampMs - targetMs).abs();
      return prevDiff < currDiff ? frames[lo - 1] : frames[lo];
    }
    return frames[lo];
  }

  /// Returns the swing phase for the frame nearest to [position].
  static SwingPhase? phaseAtPosition(
    List<PoseFrame> frames,
    Map<int, SwingPhase> phases,
    Duration position,
  ) {
    if (frames.isEmpty || phases.isEmpty) return null;
    final targetMs = position.inMilliseconds;

    int nearestIdx = 0;
    int minDiff = (frames[0].timestampMs - targetMs).abs();
    for (int i = 1; i < frames.length; i++) {
      final diff = (frames[i].timestampMs - targetMs).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearestIdx = i;
      }
    }
    return phases[nearestIdx];
  }

  static String phaseLabel(SwingPhase phase) {
    switch (phase) {
      case SwingPhase.setup:
        return 'Setup';
      case SwingPhase.backswing:
        return 'Backswing';
      case SwingPhase.impact:
        return 'Impact';
      case SwingPhase.followThrough:
        return 'Follow-Through';
    }
  }
}

class _ScoredTip {
  final String text;
  final int score;
  const _ScoredTip(this.text, {required this.score});
}
