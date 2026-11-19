package com.example.safeguard

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.util.Log
import androidx.camera.video.FallbackStrategy
import androidx.camera.video.FileOutputOptions
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.camera.video.VideoRecordEvent
import androidx.core.content.ContextCompat
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
import livekit.org.webrtc.VideoFrame
import livekit.org.webrtc.VideoSink
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class LiveKitManager(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner
) {
    companion object {
        private const val TAG = "LiveKitManager"
        // 720p HD with 30 FPS target and 3.5 Mbps bitrate for crystal-clear real-time streaming
        private const val VIDEO_WIDTH = 1280
        private const val VIDEO_HEIGHT = 720
        private const val VIDEO_FPS = 30
        private const val MAX_BITRATE = 3_500_000 // 3.5 Mbps for sharp, high-clarity streaming
        private const val CAPTURE_INTERVAL_MS = 15_000L // Frame capture every 15 seconds
    }

    private var room: Room? = null
    private var currentVideoTrack: LocalVideoTrack? = null
    private var cameraProvider: CameraCapturerUtils.CameraProvider? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var eventsJob: Job? = null
    private var autoCaptureJob: Job? = null

    private var frontCameraId: String? = null
    private var backCameraId: String? = null
    private var isFrontCameraActive = false

    private var currentEmergencyId: String? = null
    private var currentAuthToken: String? = null
    private var currentApiBase: String? = null
    private var captureIndex = 0

    // On-device Video Recording (CameraX VideoCapture)
    private var videoCapture: VideoCapture<Recorder>? = null
    private var activeRecording: Recording? = null
    private var currentVideoFile: File? = null
    private var recordingStartMs = 0L
    private var autoStopJob: Job? = null
    private var isEmergencyOngoing = false

    @Volatile
    private var shouldCaptureNextFrame = false

    // VideoSink to grab frames directly from the active live stream without camera conflicts
    private val frameCaptureSink = object : VideoSink {
        override fun onFrame(frame: VideoFrame) {
            if (shouldCaptureNextFrame) {
                shouldCaptureNextFrame = false
                frame.retain()
                scope.launch(Dispatchers.Default) {
                    try {
                        saveAndUploadFrame(frame)
                    } finally {
                        frame.release()
                    }
                }
            }
        }
    }

    fun startStreaming(emergencyId: String, authToken: String, apiBase: String) {
        currentEmergencyId = emergencyId
        currentAuthToken = authToken
        currentApiBase = apiBase
        captureIndex = 0
        isEmergencyOngoing = true

        scope.launch {
            try {
                // Initialize CameraX Recorder and VideoCapture UseCase
                try {
                    val recorder = Recorder.Builder()
                        .setQualitySelector(QualitySelector.from(Quality.HD, FallbackStrategy.lowerQualityOrHigherThan(Quality.SD)))
                        .build()
                    val vCap = VideoCapture.withOutput(recorder)
                    videoCapture = vCap

                    val provider = CameraXHelper.createCameraProvider(lifecycleOwner, arrayOf(vCap))
                    if (provider.isSupported(context)) {
                        CameraCapturerUtils.registerCameraProvider(provider)
                        cameraProvider = provider
                        Log.d(TAG, "CameraX provider registered successfully")
                    } else {
                        Log.w(TAG, "CameraX Provider not supported on this device, using standard Camera2")
                    }
                } catch (ce: Exception) {
                    Log.w(TAG, "CameraX registration notice (falling back to Camera2): ${ce.message}")
                }

                val cleanBase = apiBase.removeSuffix("/")
                val cleanToken = authToken.removePrefix("Bearer ").removePrefix("bearer ").trim()
                val url = URL("$cleanBase/livekit/token?emergencyId=$emergencyId&participantName=Victim&isReceiver=false")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    setRequestProperty("Authorization", "Bearer $cleanToken")
                    connectTimeout = 10000
                    readTimeout = 10000
                }

                if (conn.responseCode !in 200..299) {
                    val errText = conn.errorStream?.bufferedReader()?.readText() ?: ""
                    Log.e(TAG, "Failed to get LiveKit token: HTTP ${conn.responseCode} - $errText")
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

                // Find primary 1x cameras (select FIRST match to avoid telephoto/zoom lenses)
                val enumerator = Camera2Enumerator(context)
                frontCameraId = null
                backCameraId = null

                for (deviceName in enumerator.deviceNames) {
                    if (enumerator.isFrontFacing(deviceName) && frontCameraId == null) {
                        frontCameraId = deviceName
                    }
                    if (enumerator.isBackFacing(deviceName) && backCameraId == null) {
                        backCameraId = deviceName
                    }
                }

                if (backCameraId == null) backCameraId = "0"
                if (frontCameraId == null) frontCameraId = "1"
                Log.d(TAG, "Selected 1x Primary Cameras - Back: $backCameraId, Front: $frontCameraId")

                // Start listening for incoming data messages from receiver
                listenForDataMessages(newRoom)

                // Start periodic 15-second native frame capture from the live stream
                startAutoCaptureTimer()

                // Start with the Back Camera (1x main) by default
                isFrontCameraActive = false
                publishCamera(newRoom, backCameraId ?: "0", "back_camera")

            } catch (e: Exception) {
                Log.e(TAG, "❌ LiveKit Stream Error", e)
            }
        }
    }

    private fun startAutoCaptureTimer() {
        autoCaptureJob?.cancel()
        autoCaptureJob = scope.launch {
            delay(5000L) // Wait 5s for the initial camera stream to stabilize
            while (room != null) {
                shouldCaptureNextFrame = true
                delay(CAPTURE_INTERVAL_MS)
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
                // 1. Remove frame sink and stop old track
                currentVideoTrack?.removeRenderer(frameCaptureSink)
                currentVideoTrack?.stopCapture()
                currentVideoTrack?.let {
                    try { room.localParticipant?.unpublishTrack(it) } catch (_: Exception) {}
                }
                currentVideoTrack = null

                // 2. Allow Android Camera Hardware HAL to cleanly release the sensor
                delay(300)

                // 3. Create and publish new video track at 1x wide angle
                val track = room.localParticipant?.createVideoTrack(
                    trackName,
                    LocalVideoTrackOptions(
                        isScreencast = false,
                        deviceId = deviceId,
                        captureParams = VideoCaptureParameter(VIDEO_WIDTH, VIDEO_HEIGHT, VIDEO_FPS)
                    )
                )

                if (track != null) {
                    track.startCapture()
                    room.localParticipant?.publishVideoTrack(
                        track,
                        VideoTrackPublishOptions(
                            source = Track.Source.CAMERA,
                            videoEncoding = VideoEncoding(maxBitrate = MAX_BITRATE, maxFps = VIDEO_FPS),
                            simulcast = false
                        )
                    )
                    // Attach frame capture sink to grab live frames natively
                    track.addRenderer(frameCaptureSink)
                    currentVideoTrack = track

                    Log.d(TAG, "📸 Published: $trackName ($deviceId) at ${VIDEO_WIDTH}x${VIDEO_HEIGHT} @ ${VIDEO_FPS}fps")
                    sendCameraState()

                    // Start local on-device video recording to MP4 if not already recording
                    startLocalRecording()
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to publish $trackName", e)
            }
        }
    }

    private fun saveAndUploadFrame(frame: VideoFrame) {
        val emergencyId = currentEmergencyId ?: return
        val token = currentAuthToken ?: return
        val apiBase = currentApiBase ?: return

        val buffer = frame.buffer
        val i420 = buffer.toI420() ?: return
        try {
            val width = i420.width
            val height = i420.height
            val nv21 = i420ToNv21(i420, width, height)

            val yuvImage = YuvImage(nv21, ImageFormat.NV21, width, height, null)
            val jpegOut = ByteArrayOutputStream()
            yuvImage.compressToJpeg(Rect(0, 0, width, height), 85, jpegOut)
            val jpegBytes = jpegOut.toByteArray()

            // Handle sensor rotation
            val finalBytes = if (frame.rotation != 0) {
                val bmp = BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)
                if (bmp != null) {
                    val matrix = Matrix().apply { postRotate(frame.rotation.toFloat()) }
                    val rotated = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, matrix, true)
                    val rotatedOut = ByteArrayOutputStream()
                    rotated.compress(Bitmap.CompressFormat.JPEG, 85, rotatedOut)
                    bmp.recycle()
                    if (rotated != bmp) rotated.recycle()
                    rotatedOut.toByteArray()
                } else {
                    jpegBytes
                }
            } else {
                jpegBytes
            }

            val tempFile = File(context.cacheDir, "stream_capture_${System.currentTimeMillis()}.jpg")
            tempFile.writeBytes(finalBytes)

            val activeCam = if (isFrontCameraActive) "front" else "back"
            val idx = captureIndex++
            val cleanBase = apiBase.removeSuffix("/")
            val uploadUrl = "$cleanBase/emergency/$emergencyId/auto-image"

            scope.launch(Dispatchers.IO) {
                try {
                    Log.d(TAG, "📸 Uploading 15s stream frame #$idx ($activeCam) to $uploadUrl")
                    val ok = MultipartUploader.upload(
                        url = uploadUrl,
                        token = token,
                        file = tempFile,
                        fileField = "image",
                        fileName = tempFile.name,
                        mimeType = "image/jpeg",
                        extraFields = mapOf(
                            "camera" to activeCam,
                            "captureIndex" to idx.toString(),
                            "capturedAt" to SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                                timeZone = TimeZone.getTimeZone("UTC")
                            }.format(Date())
                        )
                    )
                    if (ok) {
                        Log.d(TAG, "✅ Stream frame #$idx ($activeCam) uploaded successfully")
                    } else {
                        Log.e(TAG, "❌ Failed to upload stream frame #$idx")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error uploading auto-capture frame", e)
                } finally {
                    tempFile.delete()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error converting video frame to JPEG", e)
        } finally {
            i420.release()
        }
    }

    private fun i420ToNv21(i420: VideoFrame.I420Buffer, width: Int, height: Int): ByteArray {
        val nv21 = ByteArray(width * height * 3 / 2)
        val yBuffer = i420.dataY
        val uBuffer = i420.dataU
        val vBuffer = i420.dataV
        val yStride = i420.strideY
        val uStride = i420.strideU
        val vStride = i420.strideV

        // Copy Y plane
        var pos = 0
        for (row in 0 until height) {
            yBuffer.position(row * yStride)
            yBuffer.get(nv21, pos, width)
            pos += width
        }

        // Interleave V and U for NV21: [V, U, V, U...]
        val uvHeight = (height + 1) / 2
        val uvWidth = (width + 1) / 2
        for (row in 0 until uvHeight) {
            for (col in 0 until uvWidth) {
                val v = vBuffer.get(row * vStride + col)
                val u = uBuffer.get(row * uStride + col)
                nv21[pos++] = v
                nv21[pos++] = u
            }
        }
        return nv21
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

    private fun startLocalRecording() {
        val vCap = videoCapture ?: return
        if (activeRecording != null || !isEmergencyOngoing) return

        try {
            val dir = File(context.cacheDir, "emergency_videos").apply { mkdirs() }
            val videoFile = File(dir, "emergency_${currentEmergencyId}_${System.currentTimeMillis()}.mp4")
            currentVideoFile = videoFile

            val outputOptions = FileOutputOptions.Builder(videoFile).build()
            val pending = vCap.output.prepareRecording(context, outputOptions)

            if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                try {
                    pending.withAudioEnabled()
                } catch (e: Exception) {
                    Log.w(TAG, "Could not enable audio for video recording", e)
                }
            }

            recordingStartMs = System.currentTimeMillis()
            activeRecording = pending.start(ContextCompat.getMainExecutor(context)) { event ->
                when (event) {
                    is VideoRecordEvent.Start -> {
                        Log.d(TAG, "🎥 On-device video recording started: ${videoFile.name}")
                    }
                    is VideoRecordEvent.Finalize -> {
                        val durationSec = if (recordingStartMs > 0) {
                            ((System.currentTimeMillis() - recordingStartMs) / 1000).toInt()
                        } else {
                            0
                        }
                        if (event.hasError()) {
                            Log.e(TAG, "❌ Video recording finalize error: code ${event.error}")
                        } else {
                            Log.d(TAG, "🎥 Video recording finalized: ${videoFile.name} (${videoFile.length()} bytes, ${durationSec}s)")
                        }

                        // Upload the recorded segment if it has valid data
                        if (videoFile.exists() && videoFile.length() > 5000) {
                            uploadRecordedVideo(videoFile, durationSec)
                        } else {
                            try { videoFile.delete() } catch (_: Exception) {}
                        }

                        activeRecording = null
                    }
                }
            }

            // Start 10-minute auto-cutoff
            start10MinTimer()
        } catch (e: Exception) {
            Log.e(TAG, "Error starting local video recording", e)
        }
    }

    private fun start10MinTimer() {
        autoStopJob?.cancel()
        autoStopJob = scope.launch {
            delay(10 * 60 * 1000L) // 10 minutes (600,000 ms)
            Log.d(TAG, "⏰ 10-minute video limit reached. Stopping video recording...")
            stopRecordingInternal()
        }
    }

    fun stopAndUploadVideo() {
        isEmergencyOngoing = false
        autoStopJob?.cancel()
        autoStopJob = null
        stopRecordingInternal()
    }

    private fun stopRecordingInternal() {
        val rec = activeRecording
        activeRecording = null
        if (rec != null) {
            try {
                rec.stop()
                rec.close()
                Log.d(TAG, "🛑 Active video recording stopped")
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping active recording", e)
            }
        }
    }

    private fun uploadRecordedVideo(file: File, durationSeconds: Int) {
        val emergencyId = currentEmergencyId ?: return
        val token = currentAuthToken ?: return
        val apiBase = currentApiBase ?: return

        scope.launch(Dispatchers.IO) {
            try {
                // Short wait to ensure file handles are fully flushed
                delay(600L)
                if (!file.exists() || file.length() < 1024) {
                    Log.w(TAG, "Video file ${file.name} invalid or empty (${file.length()} bytes)")
                    return@launch
                }

                val cleanBase = apiBase.removeSuffix("/")
                val uploadUrl = "$cleanBase/emergency/$emergencyId/video"
                Log.d(TAG, "📤 Uploading recorded video (${file.length()} bytes, ${durationSeconds}s) to $uploadUrl")

                val isoDate = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                    timeZone = TimeZone.getTimeZone("UTC")
                }.format(Date())

                val ok = MultipartUploader.upload(
                    url = uploadUrl,
                    token = token,
                    file = file,
                    fileField = "video",
                    fileName = file.name,
                    mimeType = "video/mp4",
                    extraFields = mapOf(
                        "durationSeconds" to durationSeconds.toString(),
                        "recordedAt" to isoDate
                    )
                )

                if (ok) {
                    Log.d(TAG, "✅ Recorded video ${file.name} uploaded successfully!")
                } else {
                    Log.e(TAG, "❌ Failed to upload recorded video ${file.name}")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in uploadRecordedVideo", e)
            } finally {
                try { file.delete() } catch (_: Exception) {}
            }
        }
    }

    fun stopStreaming() {
        isEmergencyOngoing = false
        eventsJob?.cancel()
        eventsJob = null
        autoCaptureJob?.cancel()
        autoCaptureJob = null
        autoStopJob?.cancel()
        autoStopJob = null

        scope.launch {
            try {
                stopRecordingInternal()
                delay(600) // allow CameraX to finalize and flush

                currentVideoTrack?.removeRenderer(frameCaptureSink)
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
