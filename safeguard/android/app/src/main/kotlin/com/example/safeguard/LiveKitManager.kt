package com.example.safeguard

import android.content.Context
import android.util.Log
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.lifecycle.LifecycleOwner
import io.livekit.android.LiveKit
import io.livekit.android.room.Room
import io.livekit.android.room.participant.VideoTrackPublishOptions
import io.livekit.android.room.track.LocalVideoTrack
import io.livekit.android.room.track.LocalVideoTrackOptions
import io.livekit.android.room.track.Track
import io.livekit.android.room.track.VideoCaptureParameter
import io.livekit.android.room.track.VideoEncoding
import io.livekit.android.room.track.video.CameraCapturerUtils
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import livekit.org.webrtc.CameraXHelper
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

class LiveKitManager(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner
) {
    companion object {
        private const val TAG = "LiveKitManager"
    }

    private var room: Room? = null
    private var frontCameraTrack: LocalVideoTrack? = null
    private var backCameraTrack: LocalVideoTrack? = null
    private var cameraProvider: CameraCapturerUtils.CameraProvider? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    fun startStreaming(emergencyId: String, authToken: String, apiBase: String) {
        scope.launch {
            try {
                // 1. Register the CameraX provider
                val provider = CameraXHelper.createCameraProvider(lifecycleOwner)
                if (provider.isSupported(context)) {
                    CameraCapturerUtils.registerCameraProvider(provider)
                    cameraProvider = provider
                    Log.d(TAG, "✅ CameraX Provider Registered")
                } else {
                    Log.e(TAG, "❌ CameraX not supported on this device")
                    return@launch
                }

                // 2. Fetch Token
                val url = URL("$apiBase/livekit/token?emergencyId=$emergencyId&participantName=Victim&isReceiver=false")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    setRequestProperty("Authorization", "Bearer $authToken")
                }
                if (conn.responseCode !in 200..299) {
                    Log.e(TAG, "❌ Failed to fetch LiveKit token")
                    return@launch
                }
                val respText = conn.inputStream.bufferedReader().readText()
                val json = JSONObject(respText)
                val lkToken = json.getString("token")
                val lkUrl = json.getString("url")

                // 3. Connect to Room
                val newRoom = LiveKit.create(context)
                newRoom.connect(lkUrl, lkToken)
                room = newRoom
                Log.d(TAG, "✅ Connected to LiveKit Room")

                // 4. Enable Microphone
                newRoom.localParticipant?.setMicrophoneEnabled(true)
                Log.d(TAG, "🎙️ Microphone Published")

                // 5. Publish Front Camera (Wrapped in try/catch)
                try {
                    val frontTrack = newRoom.localParticipant?.createVideoTrack(
                        "front_camera",
                        LocalVideoTrackOptions(
                            isScreencast = false,
                            deviceId = "1",
                            captureParams = VideoCaptureParameter(1280, 720, 20)
                        )
                    )
                    if (frontTrack != null) {
                        frontTrack.startCapture()
                        newRoom.localParticipant?.publishVideoTrack(frontTrack)
                        frontCameraTrack = frontTrack
                        Log.d(TAG, "📸 Front Camera Published")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Failed to start Front Camera", e)
                }

                // 6. Publish Back Camera (Wrapped in try/catch)
                try {
                    val backTrack = newRoom.localParticipant?.createVideoTrack(
                        "back_camera",
                        LocalVideoTrackOptions(
                            isScreencast = false,
                            deviceId = "0",
                            captureParams = VideoCaptureParameter(1280, 720, 20)
                        )
                    )
                    if (backTrack != null) {
                        backTrack.startCapture()
                        newRoom.localParticipant?.publishVideoTrack(
                            backTrack,
                            VideoTrackPublishOptions(
                                source = Track.Source.SCREEN_SHARE,
                                videoEncoding = VideoEncoding(maxBitrate = 1_000_000, maxFps = 20),
                                simulcast = false
                            )
                        )
                        backCameraTrack = backTrack
                        Log.d(TAG, "📸 Back Camera Published (as Screen Share)")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Failed to start Back Camera", e)
                }

            } catch (e: Exception) {
                Log.e(TAG, "❌ LiveKit Stream Error", e)
            }
        }
    }

    fun stopStreaming() {
        scope.launch {
            try {
                frontCameraTrack?.stopCapture()
                frontCameraTrack = null

                backCameraTrack?.stopCapture()
                backCameraTrack = null

                // Unregister the CameraX provider
                cameraProvider?.let {
                    CameraCapturerUtils.unregisterCameraProvider(it)
                    cameraProvider = null
                    Log.d(TAG, "✅ CameraX Provider Unregistered")
                }

                room?.disconnect()
                room = null

                Log.d(TAG, "🛑 LiveKit Streaming Stopped")
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping LiveKit", e)
            }
        }
    }
}