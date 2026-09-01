import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  String? _verificationId;
  bool _isPhoneVerified = false;
  String? _pendingPhone;

  AuthProvider(this._authService) {
    checkAuthStatus();
  }

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isPhoneVerified => _isPhoneVerified;
  String? get pendingPhone => _pendingPhone;

  // ============ AUTH STATUS ============

  Future<void> checkAuthStatus() async {
    try {
      _isLoading = true;
      notifyListeners();

      final token = await _authService.getToken();
      if (token != null) {
        final response = await _authService.getUserProfile();
        if (response['success'] == true) {
          _user = UserModel.fromJson(response['user']);
          _error = null;
        } else {
          _user = null;
          await _authService.clearToken();
        }
      } else {
        _user = null;
      }
    } catch (e) {
      _user = null;
      await _authService.clearToken();
      _error = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============ CHECK PHONE EXISTS ============

  Future<bool> checkPhoneExists(String phone) async {
    try {
      final response = await _authService.checkPhone(phone);
      return response['exists'] == true;
    } catch (e) {
      return false;
    }
  }

  // ============ SEND OTP ============

  Future<bool> sendOTP(String phoneNumber) async {
    try {
      _isLoading = true;
      _error = null;
      _pendingPhone = phoneNumber;
      notifyListeners();

      await _authService.sendOTP(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId) {
          _verificationId = verificationId;
          _isLoading = false;
          notifyListeners();
        },
        onError: (error) {
          _error = _getFirebaseErrorMessage(error);
          _isLoading = false;
          notifyListeners();
        },
        onAutoVerify: (credential) async {
          // ✅ CREDENTIAL IS PhoneAuthCredential
          await _handlePhoneVerification(credential);
          _isLoading = false;
          notifyListeners();
        },
      );

      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ============ VERIFY OTP ============

  Future<bool> verifyOTP(String otpCode) async {
    if (_verificationId == null) {
      _error = 'No OTP sent. Please request OTP first.';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // ✅ This returns UserCredential
      final userCredential = await _authService.verifyOTP(
        verificationId: _verificationId!,
        otpCode: otpCode,
      );

      // ✅ Handle the UserCredential
      await _handleUserCredential(userCredential);

      _isLoading = false;
      notifyListeners();
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _error = _getFirebaseErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ============ HANDLE PHONE VERIFICATION (Auto-verify) ============

  // ✅ This handles PhoneAuthCredential (for auto-verification)
  Future<void> _handlePhoneVerification(
    firebase_auth.PhoneAuthCredential credential,
  ) async {
    try {
      // Sign in with the credential
      final userCredential = await firebase_auth.FirebaseAuth.instance
          .signInWithCredential(credential);

      await _handleUserCredential(userCredential);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ============ HANDLE USER CREDENTIAL (After sign-in) ============

  // ✅ This handles UserCredential (after successful sign-in)
  Future<void> _handleUserCredential(
    firebase_auth.UserCredential userCredential,
  ) async {
    try {
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('Firebase sign-in failed');
      }

      final phone = firebaseUser.phoneNumber;
      if (phone == null) {
        throw Exception('Phone number not found');
      }

      _isPhoneVerified = true;
      _pendingPhone = phone;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ============ REGISTER USER ============

  Future<bool> registerUser({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _authService.register({
        'name': name,
        'phone': phone,
        'email': email,
        'password': password,
      });

      if (response['success'] == true) {
        _user = UserModel.fromJson(response['user']);
        await _authService.setToken(response['token']);
        _isLoading = false;
        _isPhoneVerified = false;
        _verificationId = null;
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

  // ============ LOGIN WITH PHONE ============

  Future<bool> loginWithPhone(String phone) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _authService.getUserByPhone(phone);

      if (response['success'] == true) {
        _user = UserModel.fromJson(response['user']);
        await _authService.setToken(response['token']);
        _isLoading = false;
        _isPhoneVerified = false;
        _verificationId = null;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'User not found';
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

  // ============ EMAIL LOGIN ============

  Future<bool> loginWithEmail(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _authService.loginWithEmail({
        'email': email,
        'password': password,
      });

      if (response['success'] == true) {
        _user = UserModel.fromJson(response['user']);
        await _authService.setToken(response['token']);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Invalid credentials';
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

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _authService.updateProfile(data);
      if (response['success'] == true) {
        _user = UserModel.fromJson(response['user']);
        return true;
      } else {
        _error = response['message'] ?? 'Failed to update profile';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============ LOGOUT ============

  Future<void> logout() async {
    try {
      await _authService.signOutFirebase();
    } catch (e) {
      // Ignore if Firebase sign out fails
    }
    await _authService.clearToken();
    _user = null;
    _verificationId = null;
    _isPhoneVerified = false;
    _pendingPhone = null;
    notifyListeners();
  }

  // ============ HELPERS ============

  String _getFirebaseErrorMessage(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'Invalid OTP. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'user-disabled':
        return 'User account is disabled.';
      case 'session-expired':
        return 'OTP expired. Please request a new one.';
      case 'invalid-phone-number':
        return 'Invalid phone number format. Please check and try again.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      default:
        return e.message ?? 'Verification failed. Please try again.';
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void resetPhoneVerification() {
    _verificationId = null;
    _isPhoneVerified = false;
    _pendingPhone = null;
    notifyListeners();
  }
}
