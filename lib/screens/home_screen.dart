import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'past_swings_screen.dart';
import 'record_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A2E1A), // deep dark green at top
              Color(0xFF121212), // near-black at bottom
            ],
            stops: [0.0, 0.6],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Golf icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.cardColor,
                      border: Border.all(
                        color: AppTheme.primaryGreen.withOpacity(0.4),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.golf_course,
                      size: 52,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Title
                  Text(
                    'Golf Swing\nAnalyzer',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          height: 1.2,
                        ),
                  ),
                  const SizedBox(height: 12),

                  // Subtitle
                  Text(
                    'AI-powered pose detection\n& coaching feedback',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 56),

                  // Record Swing button
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RecordScreen()),
                    ),
                    icon: const Icon(Icons.videocam, size: 22),
                    label: const Text('Record Swing'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // View Past Swings button
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PastSwingsScreen()),
                    ),
                    icon: const Icon(Icons.history, size: 22),
                    label: const Text('View Past Swings'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Footer hint
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Powered by ML Kit Pose Detection',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 12,
                                  color:
                                      AppTheme.textSecondary.withOpacity(0.7),
                                ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
