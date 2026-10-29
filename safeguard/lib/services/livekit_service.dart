import 'dart:async';

import 'package:dio/dio.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

class LiveKitService {
  Room? _room;
  bool _isStreaming = false;

  bool get isStreaming => _isStreaming;
  Room? get room => _room;

  Future<bool> startStreaming(String emergencyId) async {
    if (_isStreaming) return true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('userName') ?? 'Sender';

      // 1. Fetch Token from Backend
      final dio = Dio();
      final response = await dio.get(
        '${AppConstants.baseUrl}/livekit/token',
        queryParameters: {
          'emergencyId': emergencyId,
          'participantName': userName,
          'isReceiver': 'false',
        },
      );

      final token = response.data['token'];
      final url = response.data['url'];

      // 2. Connect to Room
      _room = Room();
      await _room!.connect(url, token);

      // 3. Publish Audio
      await _room!.localParticipant?.setMicrophoneEnabled(true);

      // 4. Publish Front Camera
      final frontTrack = await LocalVideoTrack.createCameraTrack(
        const CameraCaptureOptions(cameraPosition: CameraPosition.front),
      );
      await _room!.localParticipant?.publishVideoTrack(frontTrack);

      // 5. Publish Back Camera
      final backTrack = await LocalVideoTrack.createCameraTrack(
        const CameraCaptureOptions(cameraPosition: CameraPosition.back),
      );
      // We publish this with a specific name so the receiver knows which is which
      await _room!.localParticipant?.publishVideoTrack(
        backTrack,
        publishOptions: const VideoPublishOptions(name: 'back_camera'),
      );

      _isStreaming = true;
      print('✅ LiveKit Dual-Camera Streaming Started');
      return true;
    } catch (e) {
      print('❌ LiveKit Stream Error: $e');
      _isStreaming = false;
      return false;
    }
  }

  Future<void> stopStreaming() async {
    if (!_isStreaming) return;
    await _room?.disconnect();
    await _room?.dispose();
    _room = null;
    _isStreaming = false;
    print('🛑 LiveKit Streaming Stopped');
  }
}
