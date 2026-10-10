import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'api_service.dart';

/// ============================================================
/// CameraCaptureService
/// ============================================================
/// Captures photos every N seconds during emergency.
/// Alternates between front and back cameras.
/// Uploads each photo to backend.
/// ============================================================
class CameraCaptureService {
  final Dio _dio = Dio()
    ..options.baseUrl = ApiService.baseUrl
    ..options.connectTimeout = const Duration(seconds: 30)
    ..options.receiveTimeout = const Duration(seconds: 60);

  CameraController? _frontController;
  CameraController? _backController;
  Timer? _captureTimer;
  String? _emergencyId;
  String? _authToken;
  bool _isRunning = false;
  int _captureIndex = 0;

  // Max photos to prevent infinite storage use
  static const int _maxCaptures = 10;
  static const int _intervalSeconds = 30;

  bool get isRunning => _isRunning;
  int get captureIndex => _captureIndex;

  // ============ START ============
  Future<bool> start({
    required String emergencyId,
    required String authToken,
  }) async {
    if (_isRunning) return true;

    try {
      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('❌ No cameras available');
        return false;
      }

      // Initialize front + back controllers
      await _initializeControllers(cameras);

      _emergencyId = emergencyId;
      _authToken = authToken;
      _captureIndex = 0;
      _isRunning = true;

      // Take first photo after a short delay
      await Future.delayed(const Duration(seconds: 3));
      await _captureAndUpload();

      // Schedule subsequent captures
      _captureTimer = Timer.periodic(
        const Duration(seconds: _intervalSeconds),
        (_) => _captureAndUpload(),
      );

      print('📸 Camera auto-capture started for emergency $emergencyId');
      return true;
    } catch (e) {
      print('❌ Failed to start auto-capture: $e');
      _isRunning = false;
      return false;
    }
  }

  // ============ STOP ============
  Future<void> stop() async {
    if (!_isRunning) return;

    _isRunning = false;
    _captureTimer?.cancel();
    _captureTimer = null;

    await _disposeControllers();

    print('🛑 Camera auto-capture stopped');
  }

  // ============ INTERNAL ============
  Future<void> _initializeControllers(List<CameraDescription> cameras) async {
    final frontCam = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    final backCam = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _frontController = CameraController(
      frontCam,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _backController = CameraController(
      backCam,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _frontController!.initialize();
    await _backController!.initialize();

    print('📸 Cameras initialized');
  }

  Future<void> _disposeControllers() async {
    try {
      await _frontController?.dispose();
      await _backController?.dispose();
      _frontController = null;
      _backController = null;
    } catch (e) {
      print('⚠️ Error disposing controllers: $e');
    }
  }

  Future<void> _captureAndUpload() async {
    if (!_isRunning) return;
    if (_emergencyId == null || _authToken == null) return;

    // Stop after max captures
    if (_captureIndex >= _maxCaptures) {
      print('📸 Max captures ($_maxCaptures) reached, stopping');
      await stop();
      return;
    }

    // Alternate between front and back
    final useFront = _captureIndex % 2 == 0;
    final controller = useFront ? _frontController : _backController;
    final label = useFront ? 'front' : 'back';

    if (controller == null || !controller.value.isInitialized) {
      print('⚠️ $label camera not ready');
      return;
    }

    try {
      final XFile photo = await controller.takePicture();
      final file = File(photo.path);

      final sizeKB = (await file.length()) ~/ 1024;
      if (sizeKB < 5) {
        print('⏭️ Photo too small, skipping');
        return;
      }

      await _uploadPhoto(file: file, camera: label, index: _captureIndex);

      await file.delete();
      print('✅ Photo $_captureIndex ($label) uploaded');

      _captureIndex++;
    } catch (e) {
      print('❌ Capture error ($label): $e');
    }
  }

  Future<void> _uploadPhoto({
    required File file,
    required String camera,
    required int index,
  }) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          file.path,
          filename: 'emergency_${_emergencyId}_$camera$index.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        ),
        'camera': camera,
        'captureIndex': index.toString(),
        'capturedAt': DateTime.now().toIso8601String(),
      });

      final response = await _dio.post(
        '/emergency/$_emergencyId/auto-image',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $_authToken'}),
      );

      if (response.data['success'] == true) {
        print('✅ Auto-capture $index uploaded');
      } else {
        print('❌ Upload failed: ${response.data['message']}');
      }
    } catch (e) {
      print('❌ Upload error: $e');
    }
  }
}
