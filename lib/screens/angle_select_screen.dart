import 'package:flutter/material.dart';

import '../models/swing_analysis_result.dart';
import '../theme/app_theme.dart';
import 'record_screen.dart';

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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
              'Different angles reveal different swing faults. Pick the one that matches how you\'ll set up your phone.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
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
              onTap: () => _navigate(context, SwingAngle.faceOn),
            ),
            const SizedBox(height: 16),
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
              onTap: () => _navigate(context, SwingAngle.downTheLine),
            ),
            const Spacer(),
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
}

class _AngleCard extends StatelessWidget {
  final SwingAngle angle;
  final String title;
  final String subtitle;
  final List<String> bullets;
  final IconData icon;
  final VoidCallback onTap;

  const _AngleCard({
    required this.angle,
    required this.title,
    required this.subtitle,
    required this.bullets,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryGreen.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryGreen.withOpacity(0.15),
                border: Border.all(
                  color: AppTheme.primaryGreen.withOpacity(0.5),
                ),
              ),
              child: Icon(icon, color: AppTheme.primaryGreen, size: 26),
            ),
            const SizedBox(width: 16),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: AppTheme.primaryGreen,
                        size: 14,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
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
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.only(right: 8),
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
    );
  }
}

class _CameraSetupTip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline,
              color: AppTheme.primaryGreen, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Place your phone ~8 feet away at hip height. Make sure your entire body is visible in the frame.',
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
