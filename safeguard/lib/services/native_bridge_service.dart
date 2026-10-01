import 'package:flutter/services.dart';

/// Bridge for communication between Flutter and native Android.
/// Detects when the app was opened from the Quick Settings Tile.
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

  /// Register a callback for native → Flutter navigation requests.
  static void onOpenEmergencyMode(Function onOpen) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openEmergencyMode') {
        onOpen();
      }
    });
  }
}
