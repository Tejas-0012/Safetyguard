import 'package:flutter/services.dart';

/// Flutter bridge to Android's foreground service.
/// Keeps the app process alive during emergencies so audio/camera/location
/// continue running even when the app is backgrounded.
class ForegroundService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.safeguard/native',
  );

  /// Start foreground service in EMERGENCY mode.
  /// Shows notification: "🚨 SafeGuard EMERGENCY"
  static Future<bool> startEmergency() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'startEmergencyForeground',
      );
      return result ?? false;
    } catch (e) {
      print('ForegroundService.startEmergency error: $e');
      return false;
    }
  }

  /// Stop foreground service emergency mode.
  /// If shake detection is on, service keeps running with normal notification.
  static Future<bool> stopEmergency() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'stopEmergencyForeground',
      );
      return result ?? false;
    } catch (e) {
      print('ForegroundService.stopEmergency error: $e');
      return false;
    }
  }
}
