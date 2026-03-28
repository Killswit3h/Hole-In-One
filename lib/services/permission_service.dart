import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Returns true if camera permission is granted (mic is optional).
  static Future<bool> requestAll() async {
    final results = await [
      Permission.camera,
      Permission.microphone,
    ].request();
    return results[Permission.camera]?.isGranted ?? false;
  }

  static Future<bool> isMicrophoneGranted() async =>
      await Permission.microphone.isGranted;

  static Future<bool> isCameraGranted() async =>
      await Permission.camera.isGranted;

  static Future<void> openSettings() async => openAppSettings();
}
