// Simple microphone permission helper.
// Only handles microphone (no sensors).
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Request microphone permission. Returns true when granted.
Future<bool> requestMicrophonePermission() async {
  final status = await Permission.microphone.status;
  if (status.isGranted) {
    debugPrint('Microphone permission already granted');
    return true;
  }

  final result = await Permission.microphone.request();
  if (result.isGranted) {
    debugPrint('Microphone permission granted');
    return true;
  }

  if (result.isPermanentlyDenied) {
    debugPrint('Microphone permission permanently denied.');
  } else {
    debugPrint('Microphone permission denied: $result');
  }
  return false;
}