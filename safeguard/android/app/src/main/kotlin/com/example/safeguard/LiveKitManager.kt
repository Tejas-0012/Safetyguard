package com.example.safeguard

import android.content.Context
import android.util.Log
import androidx.lifecycle.LifecycleOwner
import io.livekit.android.LiveKit
import io.livekit.android.events.RoomEvent
import io.livekit.android.room.Room
import io.livekit.android.room.participant.VideoTrackPublishOptions
import io.livekit.android.room.track.DataPublishReliability
import io.livekit.android.room.track.LocalVideoTrack
import io.livekit.android.room.track.LocalVideoTrackOptions
import io.livekit.android.room.track.Track
import io.livekit.android.room.track.VideoCaptureParameter
import io.livekit.android.room.track.VideoEncoding
import io.livekit.android.room.track.video.CameraCapturerUtils
import livekit.org.webrtc.Camera2Enumerator
import livekit.org.webrtc.CameraXHelper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
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
    private var currentVideoTrack: LocalVideoTrack? = null
    private var cameraProvider: CameraCapturerUtils.CameraProvider? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var eventsJob: Job? = null

    private var frontCameraId: String? = null
    private var backCameraId: String? = null
    private var isFrontCameraActive = false

    fun startStreaming(emergencyId: String, authToken: String, apiBase: String) {
        scope.launch {
            try {
                val provider = CameraXHelper.createCameraProvider(lifecycleOwner)
                if (provider.isSupported(context)) {
                    CameraCapturerUtils.registerCameraProvider(provider)
                    cameraProvider = provider
                } else {
                    Log.e(TAG, "CameraX Provider not supported on this device")
                    return@launch
                }

                val cleanBase = apiBase.removeSuffix("/")
                val url = URL("$cleanBase/livekit/token?emergencyId=$emergencyId&participantName=Victim&isReceiver=false")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    setRequestProperty("Authorization", "Bearer $authToken")
                }

                if (conn.responseCode !in 200..299) {
                    Log.e(TAG, "Failed to get LiveKit token: HTTP ${conn.responseCode}")
                    return@launch
                }

                val respText = conn.inputStream.bufferedReader().readText()
                val json = JSONObject(respText)
                val lkToken = json.getString("token")
                val lkUrl = json.getString("url")

                val newRoom = LiveKit.create(context)
                newRoom.connect(lkUrl, lkToken)
                room = newRoom
                Log.d(TAG, "✅ Connected to LiveKit Room: $emergencyId")

                // Enable microphone
                newRoom.localParticipant?.setMicrophoneEnabled(true)
                Log.d(TAG, "🎙️ Microphone Published")

                // Find front and back cameras
                val enumerator = Camera2Enumerator(context)
                for (deviceName in enumerator.deviceNames) {
                    if (enumerator.isFrontFacing(deviceName)) frontCameraId = deviceName
                    if (enumerator.isBackFacing(deviceName)) backCameraId = deviceName
                }
                Log.d(TAG, "Cameras found - Back: $backCameraId, Front: $frontCameraId")

                // Start listening for incoming data messages (e.g. from receiver)
                listenForDataMessages(newRoom)

                // Start with the Back Camera by default
                isFrontCameraActive = false
                publishCamera(newRoom, backCameraId ?: "0", "back_camera")

            } catch (e: Exception) {
                Log.e(TAG, "❌ LiveKit Stream Error", e)
            }
        }
    }

    private fun listenForDataMessages(r: Room) {
        eventsJob?.cancel()
        eventsJob = scope.launch {
            try {
                r.events.events.collect { event ->
                    if (event is RoomEvent.DataReceived) {
                        handleIncomingData(event.data)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error collecting room events", e)
            }
        }
    }

    private fun handleIncomingData(data: ByteArray) {
        try {
            val text = String(data, Charsets.UTF_8)
            Log.d(TAG, "📩 LiveKit Data Message received: $text")
            val json = JSONObject(text)
            val action = json.optString("action")
            if (action.equals("SWITCH_CAMERA", ignoreCase = true)) {
                val target = if (json.has("target")) json.optString("target") else null
                Log.d(TAG, "🔄 Receiver requested camera switch to: $target")
                switchCamera(target)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse incoming data packet", e)
        }
    }

    fun switchCamera(target: String? = null) {
        val r = room ?: return
        val switchToFront = when (target?.lowercase()) {
            "front" -> true
            "back" -> false
            else -> !isFrontCameraActive
        }

        if (switchToFront == isFrontCameraActive && currentVideoTrack != null) {
            // Already active on requested camera, re-send confirmation
            sendCameraState()
            return
        }

        isFrontCameraActive = switchToFront
        val targetId = if (isFrontCameraActive) (frontCameraId ?: "1") else (backCameraId ?: "0")
        val trackName = if (isFrontCameraActive) "front_camera" else "back_camera"

        publishCamera(r, targetId, trackName)
    }

    private fun publishCamera(room: Room, deviceId: String, trackName: String) {
        scope.launch {
            try {
                // 1. Stop and unpublish existing track
                currentVideoTrack?.stopCapture()
                currentVideoTrack?.let {
                    try { room.localParticipant?.unpublishTrack(it) } catch (_: Exception) {}
                }
                currentVideoTrack = null

                // 2. Short delay allowing Android Camera Hardware / HAL to cleanly release the sensor
                delay(300)

                // 3. Create and publish new video track
                val track = room.localParticipant?.createVideoTrack(
                    trackName,
                    LocalVideoTrackOptions(
                        isScreencast = false,
                        deviceId = deviceId,
                        captureParams = VideoCaptureParameter(640, 480, 15)
                    )
                )

                if (track != null) {
                    track.startCapture()
                    room.localParticipant?.publishVideoTrack(
                        track,
                        VideoTrackPublishOptions(
                            source = Track.Source.CAMERA,
                            videoEncoding = VideoEncoding(maxBitrate = 400_000, maxFps = 15),
                            simulcast = false
                        )
                    )
                    currentVideoTrack = track
                    Log.d(TAG, "📸 Published: $trackName (device: $deviceId)")
                    sendCameraState()
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to publish $trackName", e)
            }
        }
    }

    private fun sendCameraState() {
        scope.launch {
            try {
                val state = JSONObject().apply {
                    put("type", "CAMERA_STATE")
                    put("activeCamera", if (isFrontCameraActive) "front" else "back")
                }
                val payload = state.toString().toByteArray(Charsets.UTF_8)
                room?.localParticipant?.publishData(payload, DataPublishReliability.RELIABLE)
                Log.d(TAG, "📤 Sent camera state to room: ${if (isFrontCameraActive) "front" else "back"}")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send camera state", e)
            }
        }
    }

    fun stopStreaming() {
        eventsJob?.cancel()
        eventsJob = null

        scope.launch {
            try {
                currentVideoTrack?.stopCapture()
                currentVideoTrack = null

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
