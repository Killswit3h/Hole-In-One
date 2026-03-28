import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/pose_frame.dart';
import '../models/swing_recording.dart';

class StorageService {
  static const _appDir = 'golf_swing_analyzer';
  static const _swingsDir = 'golf_swing_analyzer/swings';
  static const _indexFileName = 'recordings_index.json';

  static Future<Directory> _getRootDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_appDir');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> _getIndexFile() async {
    final root = await _getRootDir();
    return File('${root.path}/$_indexFileName');
  }

  /// Allocates directory and paths for a new recording.
  static Future<({String videoPath, String posesPath})> allocateRecordingPaths(
      String id) async {
    final docs = await getApplicationDocumentsDirectory();
    final swingDir = Directory('${docs.path}/$_swingsDir/$id');
    await swingDir.create(recursive: true);
    return (
      videoPath: '${swingDir.path}/video.mp4',
      posesPath: '${swingDir.path}/poses.json',
    );
  }

  /// Saves pose frames JSON and appends recording to the index.
  static Future<SwingRecording> saveRecording({
    required String id,
    required String videoPath,
    required String posesPath,
    required List<PoseFrame> poseFrames,
    required int durationMs,
  }) async {
    // Write poses JSON
    final posesFile = File(posesPath);
    final posesJson =
        jsonEncode(poseFrames.map((f) => f.toJson()).toList());
    await posesFile.writeAsString(posesJson);

    final recording = SwingRecording(
      id: id,
      videoPath: videoPath,
      posesPath: posesPath,
      timestamp: DateTime.now(),
      durationMs: durationMs,
    );

    // Append to index
    final all = await loadAllRecordings();
    all.add(recording);
    await _writeIndex(all);

    return recording;
  }

  static Future<List<SwingRecording>> loadAllRecordings() async {
    final indexFile = await _getIndexFile();
    if (!await indexFile.exists()) return [];

    try {
      final content = await indexFile.readAsString();
      final list = jsonDecode(content) as List;
      final recordings = list
          .map((e) => SwingRecording.fromJson(e as Map<String, dynamic>))
          .toList();
      // Filter out recordings whose video files no longer exist
      final valid = <SwingRecording>[];
      for (final r in recordings) {
        if (await File(r.videoPath).exists()) valid.add(r);
      }
      return valid;
    } catch (_) {
      return [];
    }
  }

  static Future<List<PoseFrame>> loadPoseFrames(String posesPath) async {
    final file = File(posesPath);
    if (!await file.exists()) return [];
    try {
      final content = await file.readAsString();
      final list = jsonDecode(content) as List;
      return list
          .map((e) => PoseFrame.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> deleteRecording(String id) async {
    final docs = await getApplicationDocumentsDirectory();
    final swingDir = Directory('${docs.path}/$_swingsDir/$id');
    if (await swingDir.exists()) await swingDir.delete(recursive: true);

    final all = await loadAllRecordings();
    all.removeWhere((r) => r.id == id);
    await _writeIndex(all);
  }

  static Future<void> _writeIndex(List<SwingRecording> recordings) async {
    final indexFile = await _getIndexFile();
    final json = jsonEncode(recordings.map((r) => r.toJson()).toList());
    await indexFile.writeAsString(json);
  }
}
