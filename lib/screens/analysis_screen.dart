import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/pose_frame.dart';
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
  bool _isVideoInitialized = false;
  bool _isLoading = true;
  String? _errorMessage;

  List<PoseFrame> _poseFrames = [];
  Map<int, SwingPhase> _phases = {};
  List<String> _tips = [];

  PoseFrame? _currentFrame;
  SwingPhase? _currentPhase;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onVideoPositionChanged);
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Load pose frames
      _poseFrames =
          await StorageService.loadPoseFrames(widget.recording.posesPath);

      // Initialize video controller
      final file = File(widget.recording.videoPath);
      final controller = VideoPlayerController.file(file);
      await controller.initialize();

      // Run analysis
      _phases = PoseAnalysisService.detectSwingPhases(_poseFrames);
      _tips = PoseAnalysisService.generateTips(_poseFrames, _phases);

      controller.addListener(_onVideoPositionChanged);

      if (!mounted) return;
      setState(() {
        _videoController = controller;
        _isVideoInitialized = true;
        _isLoading = false;
        // Set initial frame
        if (_poseFrames.isNotEmpty) {
          _currentFrame = _poseFrames.first;
          _currentPhase = _phases[0];
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load recording: $e';
        });
      }
    }
  }

  void _onVideoPositionChanged() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    final position = controller.value.position;
    final frame =
        PoseAnalysisService.findNearestFrame(_poseFrames, position);
    final phase = PoseAnalysisService.phaseAtPosition(
        _poseFrames, _phases, position);

    if (frame != _currentFrame || phase != _currentPhase) {
      setState(() {
        _currentFrame = frame;
        _currentPhase = phase;
      });
    }
  }

  void _togglePlayPause() {
    final controller = _videoController;
    if (controller == null) return;
    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen))
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
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Video + skeleton overlay
        _buildVideoSection(),

        // Video controls
        _buildVideoControls(),

        // Divider
        const Divider(height: 1, color: Color(0xFF2E2E2E)),

        // Analysis panel
        Expanded(child: _buildAnalysisPanel()),
      ],
    );
  }

  Widget _buildVideoSection() {
    final controller = _videoController!;
    final videoSize = controller.value.size;
    final aspectRatio = videoSize.width > 0 && videoSize.height > 0
        ? videoSize.width / videoSize.height
        : 16 / 9;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video
          VideoPlayer(controller),

          // Skeleton overlay
          CustomPaint(
            painter: SkeletonPainter(frame: _currentFrame),
          ),

          // Swing phase label
          if (_currentPhase != null)
            Positioned(
              bottom: 10,
              left: 12,
              child: _buildPhaseChip(_currentPhase!),
            ),
        ],
      ),
    );
  }

  Widget _buildPhaseChip(SwingPhase phase) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryGreen, width: 1),
      ),
      child: Text(
        PoseAnalysisService.phaseLabel(phase),
        style: const TextStyle(
          color: AppTheme.primaryGreen,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildVideoControls() {
    final controller = _videoController!;
    return Container(
      color: AppTheme.surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scrubber
          VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: AppTheme.primaryGreen,
              bufferedColor: Color(0xFF4CAF5040),
              backgroundColor: Color(0xFF333333),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
          ),

          // Play/pause + time
          Row(
            children: [
              IconButton(
                icon: Icon(
                  controller.value.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: AppTheme.primaryGreen,
                  size: 36,
                ),
                onPressed: _togglePlayPause,
              ),
              const SizedBox(width: 4),
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  return Text(
                    '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  );
                },
              ),
              const Spacer(),
              // Replay button
              IconButton(
                icon: const Icon(Icons.replay, color: AppTheme.textSecondary),
                onPressed: () {
                  controller.seekTo(Duration.zero);
                  controller.play();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Joint angles section
          _buildSectionHeader('Joint Angles', Icons.straighten),
          const SizedBox(height: 12),
          _buildAnglesRow(),
          const SizedBox(height: 20),

          // Coaching tips section
          _buildSectionHeader('Coaching Tips', Icons.tips_and_updates),
          const SizedBox(height: 12),
          ..._tips.asMap().entries.map((e) => _buildTipCard(e.key + 1, e.value)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAnglesRow() {
    final angles = _currentFrame != null
        ? PoseAnalysisService.calculateAngles(_currentFrame!)
        : null;

    return Row(
      children: [
        Expanded(
          child: _buildAngleChip(
            label: 'Shoulders',
            value: angles != null
                ? '${angles.shoulderRotation.toStringAsFixed(0)}°'
                : '--',
            icon: Icons.accessibility_new,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildAngleChip(
            label: 'Hips',
            value: angles != null
                ? '${angles.hipRotation.toStringAsFixed(0)}°'
                : '--',
            icon: Icons.swap_vert,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildAngleChip(
            label: 'Lead Elbow',
            value: angles != null
                ? '${angles.leftElbowBend.toStringAsFixed(0)}°'
                : '--',
            icon: Icons.change_history,
          ),
        ),
      ],
    );
  }

  Widget _buildAngleChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3A3A), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.primaryGreen, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(int number, String tip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryGreen.withOpacity(0.3),
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
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
