import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/pose_frame.dart';
import '../models/swing_analysis_result.dart';
import '../models/swing_recording.dart';
import '../services/pose_analysis_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/skeleton_painter.dart';

class AnalysisScreen extends StatefulWidget {
  final SwingRecording recording;

  const AnalysisScreen({super.key, required this.recording});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  VideoPlayerController? _videoController;
  bool _isLoading = true;
  String? _errorMessage;

  List<PoseFrame> _frames = [];
  Map<int, SwingPhase> _phases = {};
  SwingAnalysisResult? _result;

  PoseFrame? _currentFrame;
  SwingPhase? _currentPhase;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onVideoTick);
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      _frames = await StorageService.loadPoseFrames(widget.recording.posesPath);

      final controller =
          VideoPlayerController.file(File(widget.recording.videoPath));
      await controller.initialize();

      _phases = PoseAnalysisService.detectSwingPhases(_frames);
      _result = PoseAnalysisService.analyzeSwing(_frames, _phases);

      controller.addListener(_onVideoTick);

      if (!mounted) return;
      setState(() {
        _videoController = controller;
        _isLoading = false;
        if (_frames.isNotEmpty) {
          _currentFrame = _frames.first;
          _currentPhase = _phases[0];
        }
      });
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = '$e'; });
    }
  }

  void _onVideoTick() {
    final c = _videoController;
    if (c == null || !c.value.isInitialized) return;
    final frame = PoseAnalysisService.findNearestFrame(_frames, c.value.position);
    final phase = PoseAnalysisService.phaseAtPosition(_frames, _phases, c.value.position);
    if (frame != _currentFrame || phase != _currentPhase) {
      setState(() { _currentFrame = frame; _currentPhase = phase; });
    }
  }

  void _seekToFrame(int? frameIdx) {
    if (frameIdx == null || _videoController == null) return;
    final ms = _frames[frameIdx].timestampMs;
    _videoController!.seekTo(Duration(milliseconds: ms));
    setState(() {
      _currentFrame = _frames[frameIdx];
      _currentPhase = _phases[frameIdx];
    });
  }

  void _togglePlay() {
    final c = _videoController;
    if (c == null) return;
    setState(() => c.value.isPlaying ? c.pause() : c.play());
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text('Swing Analysis'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _errorMessage != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final result = _result!;
    final faultedLandmarks = _currentFrame != null
        ? result.faultedLandmarks
        : <String>{};

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Video + skeleton ────────────────────────────────────────────────
          _buildVideoSection(faultedLandmarks),

          // ── Phase strip ─────────────────────────────────────────────────────
          _buildPhaseStrip(result),

          // ── Video controls ──────────────────────────────────────────────────
          _buildVideoControls(),

          const SizedBox(height: 16),

          // ── Swing score ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildScoreCard(result),
          ),

          const SizedBox(height: 12),

          // ── Top priority fault ───────────────────────────────────────────────
          if (result.topPriorityFault != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildTopPriorityCard(result.topPriorityFault!),
            ),

          const SizedBox(height: 12),

          // ── Timing bar ───────────────────────────────────────────────────────
          if (result.tempoRatio > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildTempoCard(result),
            ),

          const SizedBox(height: 12),

          // ── All checks ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildAllChecks(result),
          ),

          const SizedBox(height: 12),

          // ── Coaching tips ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildTipsSection(result),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── VIDEO SECTION ──────────────────────────────────────────────────────────

  Widget _buildVideoSection(Set<String> faultedLandmarks) {
    final c = _videoController!;
    final size = c.value.size;
    final ar = size.width > 0 && size.height > 0
        ? size.width / size.height
        : 9 / 16;

    return AspectRatio(
      aspectRatio: ar,
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoPlayer(c),
          CustomPaint(
            painter: SkeletonPainter(
              frame: _currentFrame,
              faultedLandmarks: faultedLandmarks,
            ),
          ),
        ],
      ),
    );
  }

  // ─── PHASE STRIP ────────────────────────────────────────────────────────────

  Widget _buildPhaseStrip(SwingAnalysisResult result) {
    return Container(
      color: AppTheme.surfaceColor,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _PhaseButton(
            label: 'S',
            fullLabel: 'Setup',
            isActive: _currentPhase == SwingPhase.setup,
            onTap: () => _seekToFrame(result.setupFrameIdx),
            enabled: result.setupFrameIdx != null,
          ),
          _phaseArrow(),
          _PhaseButton(
            label: 'B',
            fullLabel: 'Top',
            isActive: _currentPhase == SwingPhase.backswing ||
                _currentPhase == SwingPhase.top,
            onTap: () => _seekToFrame(result.backswingPeakIdx),
            enabled: result.backswingPeakIdx != null,
          ),
          _phaseArrow(),
          _PhaseButton(
            label: 'I',
            fullLabel: 'Impact',
            isActive: _currentPhase == SwingPhase.downswing ||
                _currentPhase == SwingPhase.impact,
            onTap: () => _seekToFrame(result.impactFrameIdx),
            enabled: result.impactFrameIdx != null,
          ),
          _phaseArrow(),
          _PhaseButton(
            label: 'F',
            fullLabel: 'Finish',
            isActive: _currentPhase == SwingPhase.finish,
            onTap: () => _seekToFrame(result.finishFrameIdx),
            enabled: result.finishFrameIdx != null,
          ),
        ],
      ),
    );
  }

  Widget _phaseArrow() => const Icon(
        Icons.chevron_right,
        color: Color(0xFF444444),
        size: 18,
      );

  // ─── VIDEO CONTROLS ─────────────────────────────────────────────────────────

  Widget _buildVideoControls() {
    final c = _videoController!;
    return Container(
      color: AppTheme.surfaceColor,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VideoProgressIndicator(
            c,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: AppTheme.primaryGreen,
              bufferedColor: Color(0xFF4CAF5040),
              backgroundColor: Color(0xFF333333),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  c.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: AppTheme.primaryGreen,
                  size: 36,
                ),
                onPressed: _togglePlay,
              ),
              const SizedBox(width: 4),
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: c,
                builder: (_, val, __) => Text(
                  '${_fmt(val.position)} / ${_fmt(val.duration)}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ),
              const Spacer(),
              // Phase label
              if (_currentPhase != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.5)),
                  ),
                  child: Text(
                    PoseAnalysisService.phaseLabel(_currentPhase!),
                    style: const TextStyle(
                      color: AppTheme.primaryGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.replay, color: AppTheme.textSecondary),
                onPressed: () {
                  _videoController!.seekTo(Duration.zero);
                  _videoController!.play();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── SCORE CARD ─────────────────────────────────────────────────────────────

  Widget _buildScoreCard(SwingAnalysisResult result) {
    final score = result.score;
    final color = _scoreColor(score);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SWING SCORE',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  color: color,
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  ' / 100',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 18),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _scoreLabel(score),
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_frames.length} frames analyzed',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Score bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFF333333),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),

          const SizedBox(height: 16),

          // Strength badges
          Row(
            children: [
              const Text(
                'Strengths: ',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              if (result.tempoStrength) _strengthBadge('Tempo'),
              if (result.stabilityStrength) _strengthBadge('Stability'),
              if (result.impactStrength) _strengthBadge('Impact'),
              if (!result.tempoStrength && !result.stabilityStrength && !result.impactStrength)
                const Text(
                  'Keep practicing!',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _strengthBadge(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.primaryGreen,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF4CAF50);
    if (score >= 60) return const Color(0xFFFFB300);
    if (score >= 40) return const Color(0xFFFF7043);
    return const Color(0xFFFF5252);
  }

  String _scoreLabel(int score) {
    if (score >= 85) return 'Excellent';
    if (score >= 70) return 'Good';
    if (score >= 55) return 'Average';
    if (score >= 40) return 'Needs Work';
    return 'Beginner';
  }

  // ─── TOP PRIORITY FAULT ──────────────────────────────────────────────────────

  Widget _buildTopPriorityCard(SwingFault fault) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              const Text(
                'TOP PRIORITY',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            fault.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            fault.description,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.fitness_center, color: AppTheme.primaryGreen, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fault.fix,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TEMPO CARD ─────────────────────────────────────────────────────────────

  Widget _buildTempoCard(SwingAnalysisResult result) {
    final ratio = result.tempoRatio;
    final isGood = ratio >= 2.0 && ratio <= 4.5;
    final backSec = result.backswingMs / 1000;
    final downSec = result.downswingMs / 1000;

    // Normalise bar widths
    final total = result.backswingMs + result.downswingMs;
    final backFrac = total > 0 ? result.backswingMs / total : 0.6;
    final downFrac = total > 0 ? result.downswingMs / total : 0.4;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E2E2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppTheme.primaryGreen, size: 16),
              const SizedBox(width: 8),
              const Text(
                'SWING TEMPO',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${ratio.toStringAsFixed(1)} : 1',
                style: TextStyle(
                  color: isGood ? AppTheme.primaryGreen : Colors.orange,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                isGood ? Icons.check_circle : Icons.info_outline,
                color: isGood ? AppTheme.primaryGreen : Colors.orange,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TempoBar(
            label: 'Backswing',
            seconds: backSec,
            fraction: backFrac,
            color: const Color(0xFF4CAF50),
          ),
          const SizedBox(height: 8),
          _TempoBar(
            label: 'Downswing',
            seconds: downSec,
            fraction: downFrac,
            color: const Color(0xFF42A5F5),
          ),
          const SizedBox(height: 10),
          Text(
            isGood
                ? 'Great tempo! Ideal ratio is 3 : 1.'
                : ratio < 2.0
                    ? 'Rushing the takeaway — slow your backswing down.'
                    : 'Very slow backswing — maintain rhythm and momentum.',
            style: TextStyle(
              color: isGood ? AppTheme.textSecondary : Colors.orange,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ─── ALL CHECKS ─────────────────────────────────────────────────────────────

  Widget _buildAllChecks(SwingAnalysisResult result) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E2E2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SWING CHECKS',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...result.faults.map((f) => _FaultRow(fault: f)),
        ],
      ),
    );
  }

  // ─── TIPS ────────────────────────────────────────────────────────────────────

  Widget _buildTipsSection(SwingAnalysisResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppTheme.primaryGreen, size: 16),
              SizedBox(width: 8),
              Text(
                'COACHING TIPS',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ...result.tips.asMap().entries.map(
          (e) => _TipCard(number: e.key + 1, tip: e.value),
        ),
      ],
    );
  }
}

// ─── SUB-WIDGETS ──────────────────────────────────────────────────────────────

class _PhaseButton extends StatelessWidget {
  final String label;
  final String fullLabel;
  final bool isActive;
  final bool enabled;
  final VoidCallback onTap;

  const _PhaseButton({
    required this.label,
    required this.fullLabel,
    required this.isActive,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.primaryGreen : AppTheme.textSecondary;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? AppTheme.primaryGreen.withOpacity(0.2)
                  : Colors.transparent,
              border: Border.all(
                color: isActive
                    ? AppTheme.primaryGreen
                    : enabled
                        ? const Color(0xFF444444)
                        : const Color(0xFF2A2A2A),
                width: isActive ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: enabled ? color : const Color(0xFF3A3A3A),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fullLabel,
            style: TextStyle(
              color: isActive ? AppTheme.primaryGreen : const Color(0xFF555555),
              fontSize: 9,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _TempoBar extends StatelessWidget {
  final String label;
  final double seconds;
  final double fraction;
  final Color color;

  const _TempoBar({
    required this.label,
    required this.seconds,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFF333333),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${seconds.toStringAsFixed(1)}s',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _FaultRow extends StatelessWidget {
  final SwingFault fault;

  const _FaultRow({required this.fault});

  @override
  Widget build(BuildContext context) {
    final pass = !fault.detected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            pass ? Icons.check_circle : Icons.cancel,
            color: pass ? AppTheme.primaryGreen : Colors.red,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fault.name,
              style: TextStyle(
                color: pass ? Colors.white : Colors.white,
                fontSize: 13,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: pass
                  ? AppTheme.primaryGreen.withOpacity(0.15)
                  : Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              pass ? 'PASS' : 'FAULT',
              style: TextStyle(
                color: pass ? AppTheme.primaryGreen : Colors.red,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final int number;
  final String tip;

  const _TipCard({required this.number, required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryGreen.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryGreen,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
