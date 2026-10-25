import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/shake_service.dart';
import '../services/voice_service.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isShakeEnabled = false;
  bool _isVoiceEnabled = false;

  bool get isShakeEnabled => _isShakeEnabled;
  bool get isVoiceEnabled => _isVoiceEnabled;

  SettingsProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isShakeEnabled = prefs.getBool('safeguard_shake_enabled') ?? false;
    _isVoiceEnabled = prefs.getBool('safeguard_voice_enabled') ?? false;
    notifyListeners();
  }

  Future<void> toggleShake(bool value) async {
    _isShakeEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('safeguard_shake_enabled', value);

    if (value) {
      await ShakeService.start();
    } else {
      await ShakeService.stop();
    }
  }

  Future<void> toggleVoice(bool value) async {
    _isVoiceEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('safeguard_voice_enabled', value);

    if (value) {
      await VoiceService.start();
    } else {
      await VoiceService.stop();
    }
  }
}
