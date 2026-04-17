import 'dart:io';

import 'package:flutter/material.dart';

import '../models/swing_analysis_result.dart';
import '../services/storage_service.dart';
import '../services/video_analysis_service.dart';
import '../theme/app_theme.dart';
import 'analysis_screen.dart';

class VideoProcessingScreen extends StatefulWidget {
  final String videoPath;
  final SwingAngle angle;

  const VideoProcessingScreen({
    super.key,
    required this.videoPath,
    required this.angle,
  });

  @override
  State<VideoProcessingScreen> createState() => _VideoProcessingScreenState();
}

class _VideoProcessingScreenState extends State<VideoProcessingScreen> {
  double _progress = 0.0;
  String _status = 'Preparing…';
  bool _failed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _process();
  }

  Future<void> _process() async {
    try {
      // Run frame-by-frame pose detection on the uploaded video
      final frames = await VideoAnalysisService.analyze(
        videoPath: widget.videoPath,
        onProgress: (p, s) {
          if (mounted) setState(() { _progress = p; _status = s; });
        },
      );

      if (!mounted) return;
      setState(() => _status = 'Saving recording…');

      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final paths = await StorageService.allocateRecordingPaths(id);

      // Copy the user's video to permanent app storage
      await File(widget.videoPath).copy(paths.videoPath);

      final durationMs = frames.isNotEmpty ? frames.last.timestampMs : 0;

      final recording = await StorageService.saveRecording(
        id: id,
        videoPath: paths.videoPath,
        posesPath: paths.posesPath,
        poseFrames: frames,
        durationMs: durationMs,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisScreen(recording: recording),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _failed = true;
          _errorMessage = 'Processing failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text('Analyzing Video'),
        leading: _failed
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        automaticallyImplyLeading: _failed,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _failed ? _buildError() : _buildProgress(),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated icon
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primaryGreen.withOpacity(0.12),
            border: Border.all(
              color: AppTheme.primaryGreen.withOpacity(0.4),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.sports_golf,
            color: AppTheme.primaryGreen,
            size: 42,
          ),
        ),
        const SizedBox(height: 32),

        const Text(
          'Analyzing Your Swing',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Running AI pose detection on each frame',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 40),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 8,
            backgroundColor: const Color(0xFF2A2A2A),
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
          ),
        ),
        const SizedBox(height: 14),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _status,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              '${(_progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: AppTheme.primaryGreen,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),

        // Info chips
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            _InfoChip(
              icon: Icons.speed,
              label: '10 fps analysis',
            ),
            _InfoChip(
              icon: Icons.device_hub,
              label: 'On-device AI',
            ),
            _InfoChip(
              icon: Icons.lock_outline,
              label: 'Private & local',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 64),
        const SizedBox(height: 20),
        const Text(
          'Processing Failed',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _errorMessage ?? 'Unknown error',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Go Back'),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2E2E2E)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.primaryGreen, size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
