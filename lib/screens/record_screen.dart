import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/pose_frame.dart';
import '../models/pose_landmark.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'analysis_screen.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

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
    final granted = await PermissionService.requestAll();
    if (!granted) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (mounted) setState(() => _errorMessage = 'No cameras found on device.');
      return;
    }

    // Prefer back camera
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
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

    if (_isRecording) {
      await _stopRecording(controller);
    } else {
      await _startRecording(controller);
    }
  }

  Future<void> _startRecording(CameraController controller) async {
    _poseFrames.clear();
    _recordingStart = DateTime.now();

    await controller.startVideoRecording();
    await controller.startImageStream(_processCameraImage);

    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording(CameraController controller) async {
    setState(() => _isSaving = true);

    try {
      // Stop image stream before stopping video
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      final xfile = await controller.stopVideoRecording();

      // Generate a unique ID from timestamp
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      // Allocate permanent storage paths
      final paths = await StorageService.allocateRecordingPaths(id);

      // Copy temp video to permanent location
      await File(xfile.path).copy(paths.videoPath);

      // Calculate duration from pose frame timestamps
      final durationMs = _poseFrames.isNotEmpty
          ? _poseFrames.last.timestampMs
          : 0;

      // Save recording (writes poses.json + updates index)
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
          return PoseLandmark(
            type: entry.key.name,
            x: (entry.value.x / image.width).clamp(0.0, 1.0),
            y: (entry.value.y / image.height).clamp(0.0, 1.0),
            likelihood: entry.value.likelihood,
          );
        }).toList();

        _poseFrames.add(PoseFrame(
          timestampMs: elapsed,
          landmarks: landmarks,
        ));
      }
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _buildInputImage(CameraImage image) {
    final controller = _controller;
    if (controller == null) return null;

    // Concatenate all plane bytes (NV21 format on Android)
    final WriteBuffer allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

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
            // Camera preview or error state
            if (_isInitialized && _controller != null)
              _buildCameraPreview()
            else
              _buildPlaceholder(),

            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(),
            ),

            // Recording indicator
            if (_isRecording)
              Positioned(
                top: 64,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildRecordingIndicator(),
                ),
              ),

            // Bottom controls
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: _buildBottomControls(),
            ),

            // Saving overlay
            if (_isSaving) _buildSavingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.previewSize!.height,
          height: _controller!.value.previewSize!.width,
          child: CameraPreview(_controller!),
        ),
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
                : const CircularProgressIndicator(
                    color: AppTheme.primaryGreen,
                  ),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography,
              size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          const Text(
            'Camera & Microphone\nPermissions Required',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => PermissionService.openSettings(),
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
          const Expanded(
            child: Text(
              'Record Swing',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 48), // balance back button
        ],
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'RECORDING',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
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
        // Pose detection hint
        if (_isRecording)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Detecting pose: ${_poseFrames.length} frames',
              style: const TextStyle(
                color: AppTheme.accentGreen,
                fontSize: 13,
              ),
            ),
          ),

        // Record button
        GestureDetector(
          onTap: _isInitialized ? _toggleRecording : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: _isRecording ? BoxShape.rectangle : BoxShape.circle,
              borderRadius:
                  _isRecording ? BorderRadius.circular(12) : null,
              color: _isRecording ? Colors.red : Colors.red,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Icon(
              _isRecording ? Icons.stop : Icons.fiber_manual_record,
              color: Colors.white,
              size: _isRecording ? 32 : 40,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _isRecording ? 'Tap to stop' : 'Tap to record',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
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
              'Saving & analyzing swing...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
