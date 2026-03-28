import 'package:flutter/material.dart';

import '../models/swing_recording.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'analysis_screen.dart';
import 'record_screen.dart';

class PastSwingsScreen extends StatefulWidget {
  const PastSwingsScreen({super.key});

  @override
  State<PastSwingsScreen> createState() => _PastSwingsScreenState();
}

class _PastSwingsScreenState extends State<PastSwingsScreen> {
  List<SwingRecording> _recordings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    final recordings = await StorageService.loadAllRecordings();
    // Sort newest first
    recordings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (mounted) {
      setState(() {
        _recordings = recordings;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRecording(SwingRecording recording) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Delete Recording',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this swing recording? This cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageService.deleteRecording(recording.id);
      await _loadRecordings();
    }
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  •  $hour:$minute $ampm';
  }

  String _formatDuration(int ms) {
    final seconds = (ms / 1000).round();
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text('Past Swings'),
        actions: [
          if (_recordings.isNotEmpty)
            TextButton(
              onPressed: _loadRecordings,
              child: const Text('Refresh',
                  style: TextStyle(color: AppTheme.primaryGreen)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _recordings.isEmpty
              ? _buildEmptyState()
              : _buildRecordingsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cardColor,
                border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.3), width: 1.5),
              ),
              child: const Icon(Icons.golf_course,
                  size: 40, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            const Text(
              'No swings recorded yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Record your first golf swing to see it here with AI analysis.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecordScreen()),
              ),
              icon: const Icon(Icons.videocam),
              label: const Text('Record Swing'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingsList() {
    return RefreshIndicator(
      color: AppTheme.primaryGreen,
      backgroundColor: AppTheme.cardColor,
      onRefresh: _loadRecordings,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _recordings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final recording = _recordings[index];
          return _buildRecordingCard(recording, index);
        },
      ),
    );
  }

  Widget _buildRecordingCard(SwingRecording recording, int index) {
    return Dismissible(
      key: Key(recording.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade800,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await _deleteRecording(recording);
        return false; // We handle deletion in _deleteRecording
      },
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AnalysisScreen(recording: recording),
          ),
        ),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF3A3A3A), width: 1),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryGreen.withOpacity(0.15),
                ),
                child: const Icon(Icons.golf_course,
                    color: AppTheme.primaryGreen, size: 24),
              ),
              const SizedBox(width: 14),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Swing ${_recordings.length - index}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(recording.timestamp),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Duration badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.primaryGreen.withOpacity(0.4), width: 1),
                ),
                child: Text(
                  _formatDuration(recording.durationMs),
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(width: 8),
              const Icon(Icons.chevron_right,
                  color: AppTheme.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
