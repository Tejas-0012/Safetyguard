import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'api_service.dart';

/// ============================================================
/// AudioRecordingService
/// ============================================================
/// Records audio in 30-second chunks during emergency.
/// Uploads each chunk to backend.
/// ============================================================
class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  final Dio _dio = Dio()
    ..options.baseUrl = ApiService.baseUrl
    ..options.connectTimeout = const Duration(seconds: 30)
    ..options.receiveTimeout = const Duration(seconds: 60);

  bool _isRecording = false;
  String? _emergencyId;
  Timer? _chunkTimer;
  DateTime? _chunkStart;
  int _chunkIndex = 0;
  String? _currentFilePath;

  bool get isRecording => _isRecording;
  int get chunkIndex => _chunkIndex;

  /// Start recording. Records in 30-second chunks.
  Future<bool> startRecording({
    required String emergencyId,
    required String authToken,
  }) async {
    if (_isRecording) return true;

    // Check mic permission
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      print('❌ Microphone permission denied');
      return false;
    }

    _emergencyId = emergencyId;
    _chunkIndex = 0;
    _isRecording = true;

    // ✅ Start first chunk
    await _startChunk(authToken);

    // ✅ Every 30 seconds, finish current chunk and start a new one
    _chunkTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _rotateChunk(authToken),
    );

    print('🎙️ Audio recording started for emergency $emergencyId');
    return true;
  }

  /// Stop recording and upload the final chunk.
  Future<void> stopRecording({required String authToken}) async {
    if (!_isRecording) return;

    _isRecording = false;
    _chunkTimer?.cancel();
    _chunkTimer = null;

    try {
      // ✅ Finish last chunk
      await _finishAndUploadChunk(authToken);
    } catch (e) {
      print('❌ Error stopping audio: $e');
    }

    print('🛑 Audio recording stopped');
  }

  // ============ INTERNAL ============

  Future<void> _startChunk(String authToken) async {
    try {
      // Create unique file path
      final dir = await getTemporaryDirectory();
      final fileName = 'emergency_${_emergencyId}_chunk_${_chunkIndex}.m4a';
      _currentFilePath = '${dir.path}/$fileName';

      // Delete if exists (from previous run)
      final file = File(_currentFilePath!);
      if (await file.exists()) {
        await file.delete();
      }

      // Start recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
        ),
        path: _currentFilePath!,
      );

      _chunkStart = DateTime.now();
      print('🎙️ Chunk $_chunkIndex started: $_currentFilePath');
    } catch (e) {
      print('❌ Failed to start audio chunk: $e');
    }
  }

  Future<void> _rotateChunk(String authToken) async {
    if (!_isRecording) return;
    await _finishAndUploadChunk(authToken);
    _chunkIndex++;
    if (_isRecording) {
      await _startChunk(authToken);
    }
  }

  Future<void> _finishAndUploadChunk(String authToken) async {
    if (_currentFilePath == null) return;

    try {
      // Stop current recording
      final path = await _recorder.stop();
      if (path == null) return;

      final file = File(path);
      if (!await file.exists()) return;

      final sizeKB = (await file.length()) ~/ 1024;
      if (sizeKB < 5) {
        // Too small, skip upload
        print('⏭️ Chunk too small ($sizeKB KB), skipping upload');
        return;
      }

      final duration = _chunkStart != null
          ? DateTime.now().difference(_chunkStart!).inSeconds
          : 30;

      await _uploadChunk(
        file: file,
        authToken: authToken,
        durationSeconds: duration,
      );

      // Delete local file after successful upload
      await file.delete();
      print('✅ Chunk $_chunkIndex uploaded and deleted');
    } catch (e) {
      print('❌ Failed to finish chunk: $e');
    }
  }

  Future<void> _uploadChunk({
    required File file,
    required String authToken,
    required int durationSeconds,
  }) async {
    if (_emergencyId == null) return;

    try {
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          file.path,
          filename: 'chunk_$_chunkIndex.m4a',
          contentType: DioMediaType('audio', 'mp4'),
        ),
        'chunkIndex': _chunkIndex.toString(),
        'durationSeconds': durationSeconds.toString(),
        'recordedAt':
            _chunkStart?.toIso8601String() ?? DateTime.now().toIso8601String(),
      });

      final response = await _dio.post(
        '/emergency/$_emergencyId/audio',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
      );

      if (response.data['success'] == true) {
        print('✅ Audio chunk $_chunkIndex uploaded');
      } else {
        print('❌ Audio upload failed: ${response.data['message']}');
      }
    } catch (e) {
      print('❌ Audio upload error: $e');
    }
  }

  /// Clean up
  Future<void> dispose() async {
    try {
      if (_isRecording) {
        await _recorder.stop();
      }
      await _recorder.dispose();
    } catch (_) {}
  }
}
