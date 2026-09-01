import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Dio _dio = Dio();
  static const String baseUrl = AppConstants.baseUrl;

  String? _verificationId;
  String? _phoneNumber;

  AuthService() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  // ============ TOKEN MANAGEMENT ============

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  // ============ FIREBASE PHONE AUTH ============

  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(FirebaseAuthException) onError,
    required Function(PhoneAuthCredential) onAutoVerify,
  }) async {
    _phoneNumber = phoneNumber;

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        onAutoVerify(credential);
      },
      verificationFailed: (FirebaseAuthException error) {
        onError(error);
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
      timeout: const Duration(seconds: 60),
    );
  }

  Future<UserCredential> verifyOTP({
    required String verificationId,
    required String otpCode,
  }) async {
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otpCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  Future<void> resendOTP({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(FirebaseAuthException) onError,
  }) async {
    await sendOTP(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onError: onError,
      onAutoVerify: (_) {},
    );
  }

  User? getCurrentFirebaseUser() {
    return _auth.currentUser;
  }

  Future<void> signOutFirebase() async {
    await _auth.signOut();
  }

  // ============ BACKEND API CALLS ============

  Future<Map<String, dynamic>> checkPhone(String phone) async {
    try {
      final response = await _dio.post(
        '/auth/check-phone',
        data: {'phone': phone},
      );
      return response.data;
    } catch (e) {
      return {'success': false, 'exists': false};
    }
  }

  Future<Map<String, dynamic>> getUserByPhone(String phone) async {
    // Uses the currently signed-in Firebase user (set by verifyOTP just
    // before this is called) to get a verified ID token, rather than
    // trusting a bare phone number - the backend verifies this token
    // server-side before issuing a login token.
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      return {
        'success': false,
        'message': 'Not signed in with Firebase. Please verify OTP again.',
      };
    }
    final idToken = await firebaseUser.getIdToken();
    final response = await _dio.post(
      '/auth/user-by-phone',
      data: {'idToken': idToken},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    final response = await _dio.post('/auth/register', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> loginWithEmail(Map<String, dynamic> data) async {
    final response = await _dio.post('/auth/login', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    _dio.options.headers['Authorization'] = 'Bearer $token';
    final response = await _dio.get('/users/profile');
    return response.data;
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    _dio.options.headers['Authorization'] = 'Bearer $token';
    final response = await _dio.put('/users/profile', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateLocation(Map<String, dynamic> data) async {
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    _dio.options.headers['Authorization'] = 'Bearer $token';
    final response = await _dio.put('/users/location', data: data);
    return response.data;
  }

  // ============ CONTACT ENDPOINTS ============

  Future<Map<String, dynamic>> getContacts() async {
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    _dio.options.headers['Authorization'] = 'Bearer $token';
    final response = await _dio.get('/contacts');
    return response.data;
  }

  Future<Map<String, dynamic>> addContact(Map<String, dynamic> data) async {
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    _dio.options.headers['Authorization'] = 'Bearer $token';
    final response = await _dio.post('/contacts', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> deleteContact(String id) async {
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    _dio.options.headers['Authorization'] = 'Bearer $token';
    final response = await _dio.delete('/contacts/$id');
    return response.data;
  }

  // ============ EMERGENCY ENDPOINTS ============

  Future<Map<String, dynamic>> startEmergency(Map<String, dynamic> data) async {
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    _dio.options.headers['Authorization'] = 'Bearer $token';
    final response = await _dio.post('/emergency/start', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateEmergencyLocation(
    String id,
    Map<String, dynamic> data,
  ) async {
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    _dio.options.headers['Authorization'] = 'Bearer $token';
    final response = await _dio.post('/emergency/$id/location', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> stopEmergency(String id) async {
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    _dio.options.headers['Authorization'] = 'Bearer $token';
    final response = await _dio.post('/emergency/$id/stop');
    return response.data;
  }

  Future<Map<String, dynamic>> getEmergencyStatus(String id) async {
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    _dio.options.headers['Authorization'] = 'Bearer $token';
    final response = await _dio.get('/emergency/$id');
    return response.data;
  }

  Future<Map<String, dynamic>> getEmergencyHistory() async {
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'No token found'};
    }
    _dio.options.headers['Authorization'] = 'Bearer $token';
    final response = await _dio.get('/emergency/history');
    return response.data;
  }
}
