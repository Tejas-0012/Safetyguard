package com.example.safeguard

import android.content.Context
import android.util.Log
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.Timer
import java.util.TimerTask

class CameraCapture(
    private val context: Context,
    private val apiBase: String,
    private val token: String,
    private val emergencyId: String,
) {
    companion object {
        private const val TAG = "CameraCapture"
        private const val INTERVAL_SECONDS = 15
    }

    private var cameraProvider: ProcessCameraProvider? = null
    private var imageCapture: ImageCapture? = null
    private var useFront = true
    private var captureIndex = 0
    private var timer: Timer? = null
    private var isRunning = false
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    fun start() {
        if (isRunning) return
        isRunning = true

        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            try {
                cameraProvider = future.get()
                bindUseCase()
                Log.d(TAG, "📸 Camera ready")

                timer = Timer().apply {
                    scheduleAtFixedRate(object : TimerTask() {
                        override fun run() { capturePhoto() }
                    }, 3000L, INTERVAL_SECONDS * 1000L)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Camera init failed", e)
            }
        }, ContextCompat.getMainExecutor(context))
    }

    fun stop() {
        isRunning = false
        timer?.cancel(); timer = null
        try { cameraProvider?.unbindAll() } catch (_: Exception) {}
        scope.cancel()
    }

    private fun bindUseCase() {
        val provider = cameraProvider ?: return
        val selector = if (useFront) CameraSelector.DEFAULT_FRONT_CAMERA
                       else CameraSelector.DEFAULT_BACK_CAMERA

        imageCapture = ImageCapture.Builder()
            .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
            .build()

        try {
            provider.unbindAll()
            val owner = context as? LifecycleOwner ?: run {
                Log.e(TAG, "Context is not LifecycleOwner")
                return
            }
            provider.bindToLifecycle(owner, selector, imageCapture)
        } catch (e: Exception) {
            Log.e(TAG, "Bind failed", e)
        }
    }

    private fun capturePhoto() {
        if (!isRunning) return
        val ic = imageCapture ?: return
        val label = if (useFront) "front" else "back"
        val dir = File(context.cacheDir, "emergency_images").apply { mkdirs() }
        val file = File(dir, "img_${captureIndex}_$label.jpg")
        val index = captureIndex

        val options = ImageCapture.OutputFileOptions.Builder(file).build()
        ic.takePicture(
            options,
            ContextCompat.getMainExecutor(context),
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                    scope.launch {
                        if (file.exists() && file.length() > 5000) {
                            uploadImage(file, index, label)
                        }
                        file.delete()
                    }
                    captureIndex++
                    useFront = !useFront
                    ContextCompat.getMainExecutor(context).execute {
                        if (isRunning) bindUseCase()
                    }
                }
                override fun onError(exc: ImageCaptureException) {
                    Log.e(TAG, "Photo error", exc)
                    captureIndex++
                }
            },
        )
    }

    private fun uploadImage(file: File, index: Int, camera: String) {
        val url = "$apiBase/emergency/$emergencyId/auto-image"
        val capturedAt = isoUtcNow()

        val ok = MultipartUploader.upload(
            url = url,
            token = token,
            file = file,
            fileField = "image",
            fileName = "img_${index}_$camera.jpg",
            mimeType = "image/jpeg",
            extraFields = mapOf(
                "camera" to camera,
                "captureIndex" to index.toString(),
                "capturedAt" to capturedAt,
            ),
        )
        Log.d(TAG, "Image $index ($camera) uploaded: $ok")
    }

    private fun isoUtcNow(): String {
        val fmt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        fmt.timeZone = TimeZone.getTimeZone("UTC")
        return fmt.format(Date())
    }
}