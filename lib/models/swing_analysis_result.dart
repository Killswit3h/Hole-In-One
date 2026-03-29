enum SwingAngle { faceOn, downTheLine }

enum FaultType {
  stanceWidth,
  shoulderTurn,
  tempo,
  sway,
  hipRotation,
  headMovement,
  flyingElbow,
  bentLeadArm,
  lossOfPosture,
  earlyExtension,
}

class SwingFault {
  final FaultType type;
  final String name;
  final String description;
  final String fix;
  final bool detected; // true = fault found
  final double severity; // 0.0–1.0 when detected
  final List<String> faultedLandmarks; // joints to highlight red

  const SwingFault({
    required this.type,
    required this.name,
    required this.description,
    required this.fix,
    required this.detected,
    this.severity = 0.0,
    this.faultedLandmarks = const [],
  });
}

class SwingAnalysisResult {
  /// 0–100 overall swing score.
  final int score;

  /// Strength badges — shown when the aspect is passing.
  final bool tempoStrength;
  final bool stabilityStrength;
  final bool impactStrength;

  final List<SwingFault> faults;
  final SwingFault? topPriorityFault;

  /// Backswing duration / downswing duration. Ideal ~3.0.
  final double tempoRatio;
  final int backswingMs;
  final int downswingMs;

  /// Key frame indices into the poses list.
  final int? setupFrameIdx;
  final int? backswingPeakIdx;
  final int? impactFrameIdx;
  final int? finishFrameIdx;

  final List<String> tips;

  const SwingAnalysisResult({
    required this.score,
    required this.tempoStrength,
    required this.stabilityStrength,
    required this.impactStrength,
    required this.faults,
    required this.topPriorityFault,
    required this.tempoRatio,
    required this.backswingMs,
    required this.downswingMs,
    this.setupFrameIdx,
    this.backswingPeakIdx,
    this.impactFrameIdx,
    this.finishFrameIdx,
    required this.tips,
  });

  /// All landmarks that should be drawn red on the current frame.
  Set<String> get faultedLandmarks {
    final result = <String>{};
    for (final f in faults) {
      if (f.detected) result.addAll(f.faultedLandmarks);
    }
    return result;
  }
}
