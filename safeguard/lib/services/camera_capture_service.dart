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

  Timer? _captureTimer;
  String? _emergencyId;
  String? _authToken;
  bool _isRunning = false;
  int _captureIndex = 0;

  // Max photos to prevent infinite storage use
  static const int _maxCaptures = 10;
  static const int _intervalSeconds = 15;

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
      final now = DateTime.now();
      print('🕐 Local: $now');
      print('🕐 ISO:   ${now.toIso8601String()}');
      print('🕐 UTC:   ${now.toUtc().toIso8601String()}');
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

    print('🛑 Camera auto-capture stopped');
  }

  // ============ INTERNAL ============
  CameraDescription? _frontCam;
  CameraDescription? _backCam;

  Future<void> _initializeControllers(List<CameraDescription> cameras) async {
    print('📸 Available cameras:');
    for (final c in cameras) {
      print(
        '   - ${c.name}, lens: ${c.lensDirection}, sensor: ${c.sensorOrientation}',
      );
    }

    // Find front camera (if it exists)
    try {
      _frontCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      print('✅ Front camera: ${_frontCam!.name}');
    } catch (e) {
      _frontCam = null;
      print('⚠️ No front camera available');
    }

    // Find back camera
    try {
      _backCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      print('✅ Back camera: ${_backCam!.name}');
    } catch (e) {
      _backCam = cameras.first;
      print('⚠️ No back camera — using default');
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
    final camera = useFront ? _frontCam : _backCam;
    final label = useFront ? 'front' : 'back';

    if (camera == null) {
      print('⚠️ $label camera not available — skipping');
      _captureIndex++;
      return;
    }

    // ✅ Create a FRESH controller for this capture
    CameraController? controller;
    try {
      controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      // ✅ Wait for camera to stabilize (fixes "capture not returned yet")
      await Future.delayed(const Duration(milliseconds: 800));

      final XFile photo = await controller.takePicture();
      final file = File(photo.path);

      final sizeKB = (await file.length()) ~/ 1024;
      if (sizeKB < 5) {
        print('⏭️ $label photo too small, skipping');
        await file.delete();
        _captureIndex++;
        return;
      }

      await _uploadPhoto(file: file, camera: label, index: _captureIndex);

      await file.delete();
      print('✅ Photo $_captureIndex ($label) uploaded (${sizeKB}KB)');

      _captureIndex++;
    } catch (e) {
      print('❌ Capture error ($label): $e');
      _captureIndex++; // Still increment to avoid infinite retry
    } finally {
      // ✅ Dispose the controller before next capture
      await controller?.dispose();
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
