package com.example.safeguard

import android.content.Context
import android.util.Log
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
import livekit.org.webrtc.Camera2Enumerator
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
                val provider = CameraXHelper.createCameraProvider(lifecycleOwner)
                if (provider.isSupported(context)) {
                    CameraCapturerUtils.registerCameraProvider(provider)
                    cameraProvider = provider
                } else {
                    return@launch
                }

                val url = URL("$apiBase/livekit/token?emergencyId=$emergencyId&participantName=Victim&isReceiver=false")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    setRequestProperty("Authorization", "Bearer $authToken")
                }
                if (conn.responseCode !in 200..299) return@launch
                
                val respText = conn.inputStream.bufferedReader().readText()
                val json = JSONObject(respText)
                val lkToken = json.getString("token")
                val lkUrl = json.getString("url")

                val newRoom = LiveKit.create(context)
                newRoom.connect(lkUrl, lkToken)
                room = newRoom
                Log.d(TAG, "✅ Connected to LiveKit Room")

                newRoom.localParticipant?.setMicrophoneEnabled(true)
                Log.d(TAG, "🎙️ Microphone Published")

                val enumerator = Camera2Enumerator(context)
                var frontCameraId: String? = null
                var backCameraId: String? = null

                for (deviceName in enumerator.deviceNames) {
                    if (enumerator.isFrontFacing(deviceName)) frontCameraId = deviceName
                    if (enumerator.isBackFacing(deviceName)) backCameraId = deviceName
                }

                // 👈 BACK CAMERA: Published as the standard CAMERA track (Primary)
                try {
                    val finalBackId = backCameraId ?: "0"
                    val backTrack = newRoom.localParticipant?.createVideoTrack(
                        "back_camera",
                        LocalVideoTrackOptions(
                            isScreencast = false,
                            deviceId = finalBackId,
                            captureParams = VideoCaptureParameter(640, 480, 15)
                        )
                    )
                    if (backTrack != null) {
                        backTrack.startCapture()
                        newRoom.localParticipant?.publishVideoTrack(
                            backTrack,
                            VideoTrackPublishOptions(
                                source = Track.Source.CAMERA, // 👈 Primary Camera
                                videoEncoding = VideoEncoding(maxBitrate = 400_000, maxFps = 15),
                                simulcast = false
                            )
                        )
                        backCameraTrack = backTrack
                        Log.d(TAG, "📸 Back Camera Published (Primary)")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Failed to start Back Camera", e)
                }

                // 👈 FRONT CAMERA: Published as SCREEN_SHARE track (PiP)
                try {
                    val finalFrontId = frontCameraId ?: "1" 
                    val frontTrack = newRoom.localParticipant?.createVideoTrack(
                        "front_camera",
                        LocalVideoTrackOptions(
                            isScreencast = false,
                            deviceId = finalFrontId,
                            captureParams = VideoCaptureParameter(640, 480, 15)
                        )
                    )
                    if (frontTrack != null) {
                        frontTrack.startCapture()
                        newRoom.localParticipant?.publishVideoTrack(
                            frontTrack,
                            VideoTrackPublishOptions(
                                source = Track.Source.SCREEN_SHARE, // 👈 Workaround for Second Camera
                                videoEncoding = VideoEncoding(maxBitrate = 400_000, maxFps = 15),
                                simulcast = false
                            )
                        )
                        frontCameraTrack = frontTrack
                        Log.d(TAG, "📸 Front Camera Published (Screen Share)")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Failed to start Front Camera", e)
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

                // Unregister the CameraX provider to prevent memory leaks
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