import 'package:flutter/services.dart';

/// Bridge for communication between Flutter and native Android.
class NativeBridgeService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.safeguard/native',
  );

  /// Check if the app was launched from the Quick Settings Tile.
  static Future<bool> wasLaunchedFromTile() async {
    try {
      final result = await _channel.invokeMethod<bool>('wasLaunchedFromTile');
      return result ?? false;
    } catch (e) {
      print('NativeBridge: wasLaunchedFromTile error: $e');
      return false;
    }
  }

  /// Acknowledge that the "from tile" flag has been consumed.
  static Future<void> clearTileLaunch() async {
    try {
      await _channel.invokeMethod('clearTileLaunch');
    } catch (e) {
      print('NativeBridge: clearTileLaunch error: $e');
    }
  }

  /// Check if the app was launched directly for an active emergency.
  static Future<bool> wasLaunchedForEmergency() async {
    try {
      final result = await _channel.invokeMethod<bool>('wasLaunchedForEmergency');
      return result ?? false;
    } catch (e) {
      print('NativeBridge: wasLaunchedForEmergency error: $e');
      return false;
    }
  }

  /// Acknowledge that the "emergency launch" flag has been consumed.
  static Future<void> clearEmergencyLaunch() async {
    try {
      await _channel.invokeMethod('clearEmergencyLaunch');
    } catch (e) {
      print('NativeBridge: clearEmergencyLaunch error: $e');
    }
  }

  /// Register callbacks for native → Flutter events.
  static void setupNativeCallbacks({
    required Function onOpenEmergency,
    required Function onStopEmergency,
  }) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openEmergencyMode') {
        onOpenEmergency();
      } else if (call.method == 'onEmergencyStopped') {
        onStopEmergency();
      }
    });
  }

  /// Deprecated convenience wrapper
  static void onOpenEmergencyMode(Function onOpen) {
    setupNativeCallbacks(
      onOpenEmergency: onOpen,
      onStopEmergency: () {},
    );
  }
}
