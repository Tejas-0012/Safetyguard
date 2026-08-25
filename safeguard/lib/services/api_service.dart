import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // static const String baseUrl = 'http://10.0.2.2:5000/api'; // Android emulator
  static const String baseUrl = 'http://10.45.70.187:5000/api';

  final Dio _dio = Dio();

  ApiService() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  Future<String?> _getToken() async {
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

  // Auth endpoints
  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    final response = await _dio.post('/auth/register', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> login(Map<String, dynamic> data) async {
    final response = await _dio.post('/auth/login', data: data);
    return response.data;
  }

  // User endpoints
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get('/users/profile');
    return response.data;
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final response = await _dio.put('/users/profile', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateLocation(Map<String, dynamic> data) async {
    final response = await _dio.put('/users/location', data: data);
    return response.data;
  }

  // Contact endpoints
  Future<Map<String, dynamic>> getContacts() async {
    final response = await _dio.get('/contacts');
    return response.data;
  }

  Future<Map<String, dynamic>> addContact(Map<String, dynamic> data) async {
    final response = await _dio.post('/contacts', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateContact(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.put('/contacts/$id', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> deleteContact(String id) async {
    final response = await _dio.delete('/contacts/$id');
    return response.data;
  }

  // Emergency endpoints
  Future<Map<String, dynamic>> startEmergency(Map<String, dynamic> data) async {
    final response = await _dio.post('/emergency/start', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateEmergencyLocation(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.post('/emergency/$id/location', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> stopEmergency(String id) async {
    final response = await _dio.post('/emergency/$id/stop');
    return response.data;
  }

  Future<Map<String, dynamic>> getEmergencyStatus(String id) async {
    final response = await _dio.get('/emergency/$id');
    return response.data;
  }

  Future<Map<String, dynamic>> getEmergencyHistory() async {
    final response = await _dio.get('/emergency/history');
    return response.data;
  }

  Future<Map<String, dynamic>> addEmergencyImage(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.post('/emergency/$id/image', data: data);
    return response.data;
  }
}
