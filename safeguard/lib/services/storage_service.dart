import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  // ============ KEYS ============
  static const String _keyToken = 'safeguard_auth_token';
  static const String _keyUserId = 'safeguard_user_id';
  static const String _keyUserName = 'safeguard_user_name';
  static const String _keyUserPhone = 'safeguard_user_phone';
  static const String _keyLastLat = 'safeguard_last_lat';
  static const String _keyLastLng = 'safeguard_last_lng';
  static const String _keyIsLoggedIn = 'safeguard_is_logged_in';
  static const String _keyShakeEnabled = 'safeguard_shake_enabled';
  static const String _keyBluetoothDeviceId = 'safeguard_bt_device_id';
  static const String _keyApiBaseUrl = 'safeguard_api_base_url';

  // ============ SAVE ============
  Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  Future<void> saveUserInfo({
    required String userId,
    required String name,
    required String phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserPhone, phone);
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  Future<void> saveLastLocation(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastLat, lat.toString());
    await prefs.setString(_keyLastLng, lng.toString());
  }

  Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, value);
  }

  Future<void> setShakeEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShakeEnabled, value);
  }

  Future<void> setBluetoothDeviceId(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBluetoothDeviceId, deviceId);
  }

  Future<void> setApiBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiBaseUrl, url);
  }

  // ============ READ ============
  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  Future<String?> getUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserPhone);
  }

  Future<Map<String, double>?> getLastLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final latStr = prefs.getString(_keyLastLat);
    final lngStr = prefs.getString(_keyLastLng);
    if (latStr == null || lngStr == null) return null;
    final lat = double.tryParse(latStr);
    final lng = double.tryParse(lngStr);
    if (lat == null || lng == null) return null;
    return {'lat': lat, 'lng': lng};
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  Future<bool> isShakeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShakeEnabled) ?? false;
  }

  Future<String?> getBluetoothDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBluetoothDeviceId);
  }

  Future<String?> getApiBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyApiBaseUrl);
  }

  // ============ CLEAR ============
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserPhone);
    await prefs.setBool(_keyIsLoggedIn, false);
    // Keep location and settings — they're useful even when logged out
  }
}
