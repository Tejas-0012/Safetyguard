import 'package:flutter/services.dart';

/// Bridge between Flutter and the native ShakeDetectionService.
class ShakeService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.safeguard/native',
  );

  /// Start the shake detection foreground service.
  static Future<bool> start() async {
    try {
      final result = await _channel.invokeMethod<bool>('startShakeDetection');
      return result ?? false;
    } catch (e) {
      print('ShakeService.start error: $e');
      return false;
    }
  }

  /// Stop the shake detection service.
  static Future<bool> stop() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopShakeDetection');
      return result ?? false;
    } catch (e) {
      print('ShakeService.stop error: $e');
      return false;
    }
  }

  /// Check if shake detection is currently running.
  static Future<bool> isRunning() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'isShakeDetectionRunning',
      );
      return result ?? false;
    } catch (e) {
      print('ShakeService.isRunning error: $e');
      return false;
    }
  }
}
