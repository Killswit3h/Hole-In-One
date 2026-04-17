import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../models/pose_frame.dart';
import '../models/pose_landmark.dart' as models;

class VideoAnalysisService {
  /// Extract frames from [videoPath] at [intervalMs] intervals, run ML Kit
  /// pose detection on each, and return the resulting [PoseFrame] list.
  ///
  /// [onProgress] receives (0–1 fraction, status string) for display.
  static Future<List<PoseFrame>> analyze({
    required String videoPath,
    void Function(double progress, String status)? onProgress,
    int intervalMs = 100, // 10 fps — good detail without being too slow
    int maxDurationMs = 30000, // cap at 30 s to keep processing reasonable
  }) async {
    final frames = <PoseFrame>[];
    final tempDir = await getTemporaryDirectory();

    final poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.single, // single-image mode for file frames
        model: PoseDetectionModel.base,
      ),
    );

    try {
      // ── Step 1: read video duration ──────────────────────────────────────
      onProgress?.call(0.0, 'Loading video…');
      final vc = VideoPlayerController.file(File(videoPath));
      await vc.initialize();
      final durationMs =
          vc.value.duration.inMilliseconds.clamp(0, maxDurationMs);
      await vc.dispose();

      if (durationMs == 0) return frames;

      // ── Step 2: build timestamp list ─────────────────────────────────────
      final timestamps = <int>[];
      for (int t = 0; t < durationMs; t += intervalMs) {
        timestamps.add(t);
      }

      // ── Step 3: extract + detect ─────────────────────────────────────────
      for (int i = 0; i < timestamps.length; i++) {
        final t = timestamps[i];
        onProgress?.call(
          i / timestamps.length,
          'Detecting pose — frame ${i + 1} of ${timestamps.length}',
        );

        try {
          // Get JPEG bytes for this timestamp
          final thumbBytes = await VideoThumbnail.thumbnailData(
            video: videoPath,
            imageFormat: ImageFormat.JPEG,
            timeMs: t,
            maxWidth: 480, // limit size for speed; pose detection is scale-invariant
            quality: 80,
          );
          if (thumbBytes == null) continue;

          // Decode to get actual pixel dimensions for normalization
          final codec = await ui.instantiateImageCodec(thumbBytes);
          final fi = await codec.getNextFrame();
          final imgW = fi.image.width.toDouble();
          final imgH = fi.image.height.toDouble();
          fi.image.dispose();
          codec.dispose();
          if (imgW == 0 || imgH == 0) continue;

          // Write to temp file — ML Kit file API is simplest cross-device
          final tempFile = File('${tempDir.path}/golf_frame_$i.jpg');
          await tempFile.writeAsBytes(thumbBytes);

          final inputImage = InputImage.fromFilePath(tempFile.path);
          final poses = await poseDetector.processImage(inputImage);

          await tempFile.delete().catchError((_) {});

          if (poses.isNotEmpty) {
            final landmarks = poses.first.landmarks.entries.map((e) {
              return models.PoseLandmark(
                type: e.key.name,
                x: (e.value.x / imgW).clamp(0.0, 1.0),
                y: (e.value.y / imgH).clamp(0.0, 1.0),
                likelihood: e.value.likelihood,
              );
            }).toList();

            frames.add(PoseFrame(timestampMs: t, landmarks: landmarks));
          }
        } catch (e) {
          debugPrint('Frame error at ${t}ms: $e');
        }
      }
    } finally {
      await poseDetector.close();
    }

    onProgress?.call(1.0, 'Done!');
    return frames;
  }
}
