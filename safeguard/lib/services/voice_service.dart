import 'package:flutter/services.dart';

class VoiceService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.safeguard/native',
  );

  static Future<bool> start() async {
    try {
      final r = await _channel.invokeMethod<bool>('startVoiceActivation');
      return r ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> stop() async {
    try {
      final r = await _channel.invokeMethod<bool>('stopVoiceActivation');
      return r ?? false;
    } catch (e) {
      return false;
    }
  }
}
