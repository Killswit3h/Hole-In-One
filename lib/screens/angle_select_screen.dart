import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/swing_analysis_result.dart';
import '../theme/app_theme.dart';
import 'record_screen.dart';
import 'video_processing_screen.dart';

class AngleSelectScreen extends StatelessWidget {
  const AngleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text('Choose Camera Angle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select recording angle',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Different angles reveal different swing faults. Pick the one that matches how you set up your camera.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // ── Face-On card ──────────────────────────────────────────────────
            _AngleCard(
              angle: SwingAngle.faceOn,
              title: 'Face-On',
              subtitle: 'Camera in front of you, perpendicular to target line',
              bullets: const [
                'Stance width & hip alignment',
                'Head movement & sway',
                'Shoulder turn & posture',
                'Tempo & hip rotation',
              ],
              icon: Icons.person,
              onRecord: () => _navigate(context, SwingAngle.faceOn),
              onUpload: () => _pickAndUpload(context, SwingAngle.faceOn),
            ),

            const SizedBox(height: 16),

            // ── Down-the-Line card ────────────────────────────────────────────
            _AngleCard(
              angle: SwingAngle.downTheLine,
              title: 'Down-the-Line',
              subtitle: 'Camera behind you, parallel to target line',
              bullets: const [
                'Swing plane & club path',
                'Spine tilt & posture',
                'Trail elbow & arm position',
                'Clubhead path (over/under)',
              ],
              icon: Icons.sports_golf,
              onRecord: () => _navigate(context, SwingAngle.downTheLine),
              onUpload: () => _pickAndUpload(context, SwingAngle.downTheLine),
            ),

            const SizedBox(height: 24),
            _CameraSetupTip(),
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context, SwingAngle angle) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecordScreen(angle: angle)),
    );
  }

  Future<void> _pickAndUpload(BuildContext context, SwingAngle angle) async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 1),
    );
    if (video == null) return;
    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoProcessingScreen(
          videoPath: video.path,
          angle: angle,
        ),
      ),
    );
  }
}

// ─── ANGLE CARD ───────────────────────────────────────────────────────────────

class _AngleCard extends StatelessWidget {
  final SwingAngle angle;
  final String title;
  final String subtitle;
  final List<String> bullets;
  final IconData icon;
  final VoidCallback onRecord;
  final VoidCallback onUpload;

  const _AngleCard({
    required this.angle,
    required this.title,
    required this.subtitle,
    required this.bullets,
    required this.icon,
    required this.onRecord,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryGreen.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // ── Main info row ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon circle
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryGreen.withOpacity(0.12),
                    border: Border.all(
                      color: AppTheme.primaryGreen.withOpacity(0.4),
                    ),
                  ),
                  child: Icon(icon, color: AppTheme.primaryGreen, size: 24),
                ),
                const SizedBox(width: 14),

                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...bullets.map(
                        (b) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.only(right: 7),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.accentGreen,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  b,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Action buttons ────────────────────────────────────────────────
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          Row(
            children: [
              // Record button
              Expanded(
                child: _ActionButton(
                  icon: Icons.videocam,
                  label: 'Record',
                  onTap: onRecord,
                  isPrimary: true,
                  isLeft: true,
                ),
              ),
              // Divider between buttons
              const SizedBox(
                height: 44,
                child: VerticalDivider(width: 1, color: Color(0xFF2A2A2A)),
              ),
              // Upload button
              Expanded(
                child: _ActionButton(
                  icon: Icons.upload_file,
                  label: 'Upload Video',
                  onTap: onUpload,
                  isPrimary: false,
                  isLeft: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isLeft;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isPrimary,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.only(
        bottomLeft: isLeft ? const Radius.circular(16) : Radius.zero,
        bottomRight: !isLeft ? const Radius.circular(16) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isPrimary ? AppTheme.primaryGreen : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? AppTheme.primaryGreen : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CAMERA SETUP TIP ─────────────────────────────────────────────────────────

class _CameraSetupTip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1A),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline,
              color: AppTheme.primaryGreen, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Tip: Place phone ~8 ft away at hip height. Make sure your entire body is in frame. Uploading a video shot by a friend works great.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
