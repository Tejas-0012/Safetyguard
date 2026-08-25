import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;
  User? _user;
  bool _isLoading = false;
  String? _error;

  AuthProvider(this._apiService) {
    loadUser();
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  Future<void> loadUser() async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _apiService.getProfile();
      if (response['success'] == true) {
        _user = User.fromJson(response['user']);
        _error = null;
      }
    } catch (e) {
      // User not authenticated - that's fine
      _error = null;
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(
    String name,
    String phone,
    String email,
    String password,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _apiService.register({
        'name': name,
        'phone': phone,
        'email': email,
        'password': password,
      });

      if (response['success'] == true) {
        await _apiService.setToken(response['token']);
        _user = User.fromJson(response['user']);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _apiService.login({
        'email': email,
        'password': password,
      });

      if (response['success'] == true) {
        await _apiService.setToken(response['token']);
        _user = User.fromJson(response['user']);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Login failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Phone login with OTP
  Future<bool> loginWithPhone(String phone, String otp) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Demo OTP verification
      if (otp == '123456') {
        // Create demo user
        _user = User(
          id: 'demo_user_123',
          name: 'Demo User',
          phone: phone,
          email: 'demo@email.com',
          isEmergencyActive: false,
        );
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Invalid OTP. Use 123456 for demo.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _apiService.clearToken();
    _user = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
