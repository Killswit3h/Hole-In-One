import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/pose_frame.dart';
import '../models/pose_landmark.dart' as models;
import '../models/swing_analysis_result.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/camera_guide_painter.dart';
import '../widgets/skeleton_painter.dart';
import 'analysis_screen.dart';

class RecordScreen extends StatefulWidget {
  final SwingAngle angle;

  const RecordScreen({super.key, required this.angle});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isSaving = false;
  bool _permissionDenied = false;
  bool _isDetecting = false;
  String? _errorMessage;

  DateTime? _recordingStart;
  final List<PoseFrame> _poseFrames = [];

  /// Latest detected frame — shown as live skeleton overlay during recording.
  PoseFrame? _latestFrame;

  late final PoseDetector _poseDetector;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _permissionDenied = false;
      _errorMessage = null;
      _isInitialized = false;
    });

    final cameraGranted = await PermissionService.requestAll();
    if (!cameraGranted) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }

    final micGranted = await PermissionService.isMicrophoneGranted();

    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Could not list cameras: $e');
      return;
    }

    if (cameras.isEmpty) {
      if (mounted) setState(() => _errorMessage = 'No cameras found on device.');
      return;
    }

    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: micGranted,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _isInitialized = true;
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Camera error: $e');
    }
  }

  Future<void> _toggleRecording() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      if (_isRecording) {
        await _stopRecording(controller);
      } else {
        await _startRecording(controller);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isRecording = false;
          _errorMessage = 'Recording error: $e';
        });
      }
    }
  }

  Future<void> _startRecording(CameraController controller) async {
    _poseFrames.clear();
    _latestFrame = null;
    _recordingStart = DateTime.now();

    await controller.startVideoRecording();

    try {
      await controller.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint('Image stream unavailable: $e');
    }

    if (mounted) setState(() => _isRecording = true);
  }

  Future<void> _stopRecording(CameraController controller) async {
    if (mounted) setState(() => _isSaving = true);

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      final xfile = await controller.stopVideoRecording();

      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final paths = await StorageService.allocateRecordingPaths(id);
      await File(xfile.path).copy(paths.videoPath);

      final durationMs =
          _poseFrames.isNotEmpty ? _poseFrames.last.timestampMs : 0;

      final recording = await StorageService.saveRecording(
        id: id,
        videoPath: paths.videoPath,
        posesPath: paths.posesPath,
        poseFrames: List.from(_poseFrames),
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
          _isSaving = false;
          _isRecording = false;
          _errorMessage = 'Failed to save recording: $e';
        });
      }
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) return;

      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isNotEmpty && _recordingStart != null) {
        final elapsed =
            DateTime.now().difference(_recordingStart!).inMilliseconds;
        final landmarks = poses.first.landmarks.entries.map((entry) {
          return models.PoseLandmark(
            type: entry.key.name,
            x: (entry.value.x / image.width).clamp(0.0, 1.0),
            y: (entry.value.y / image.height).clamp(0.0, 1.0),
            likelihood: entry.value.likelihood,
          );
        }).toList();

        final frame = PoseFrame(timestampMs: elapsed, landmarks: landmarks);
        _poseFrames.add(frame);

        // Update live skeleton
        if (mounted) setState(() => _latestFrame = frame);
      }
    } catch (e) {
      debugPrint('Pose detection error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _buildInputImage(CameraImage image) {
    if (_controller == null) return null;
    final bytes = Uint8List.fromList(
      image.planes.expand((p) => p.bytes).toList(),
    );
    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: InputImageRotation.rotation90deg,
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes[0].bytesPerRow,
    );
    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_isInitialized && _controller != null)
              _buildCameraPreview()
            else
              _buildPlaceholder(),

            Positioned(
              top: 0, left: 0, right: 0,
              child: _buildTopBar(),
            ),

            if (_isRecording)
              Positioned(
                top: 64, left: 0, right: 0,
                child: Center(child: _buildRecordingIndicator()),
              ),

            Positioned(
              bottom: 32, left: 0, right: 0,
              child: _buildBottomControls(),
            ),

            if (_isSaving) _buildSavingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    final controller = _controller!;
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Camera feed
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.previewSize!.height,
              height: controller.value.previewSize!.width,
              child: CameraPreview(controller),
            ),
          ),

          // Guide overlay (before recording)
          if (!_isRecording)
            CustomPaint(painter: CameraGuidePainter(angle: widget.angle)),

          // Live skeleton (while recording)
          if (_isRecording && _latestFrame != null)
            CustomPaint(
              painter: SkeletonPainter(frame: _latestFrame),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.black,
      child: Center(
        child: _permissionDenied
            ? _buildPermissionDenied()
            : _errorMessage != null
                ? _buildError()
                : const CircularProgressIndicator(color: AppTheme.primaryGreen),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          const Text(
            'Camera Permission Required',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: PermissionService.openSettings,
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(32),
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
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _initCamera, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _isRecording ? null : () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              _isRecording ? 'Recording…' : 'Record Swing',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Angle badge
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.5)),
            ),
            child: Text(
              widget.angle == SwingAngle.faceOn ? 'Face-On' : 'DTL',
              style: const TextStyle(
                color: AppTheme.primaryGreen,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'REC  ${_poseFrames.length} frames',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Record button
        GestureDetector(
          onTap: _isInitialized && !_isSaving ? _toggleRecording : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: _isRecording ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: _isRecording ? BorderRadius.circular(14) : null,
              color: _isInitialized ? Colors.red : Colors.red.withOpacity(0.4),
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Icon(
              _isRecording ? Icons.stop : Icons.fiber_manual_record,
              color: Colors.white,
              size: _isRecording ? 32 : 40,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _isRecording ? 'Tap to stop & analyze' : 'Tap to start recording',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSavingOverlay() {
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryGreen),
            SizedBox(height: 20),
            Text(
              'Analyzing your swing…',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Detecting faults & calculating score',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
