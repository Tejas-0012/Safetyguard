package com.example.safeguard

import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.content.ContextCompat
import com.rementia.openwakeword.lib.WakeWordEngine
import com.rementia.openwakeword.lib.model.DetectionMode
import com.rementia.openwakeword.lib.model.WakeWordModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch

class VoiceDetector(
    private val context: Context,
    private val onVoiceTriggered: () -> Unit
) {
    companion object {
        private const val TAG = "VoiceDetector"
        private const val MODEL_NAME = "code_red"
        private const val MODEL_FILE = "code_red.onnx"
        private const val THRESHOLD = 0.7f
    }

    private var wakeWordEngine: WakeWordEngine? = null
    private var voiceJob: Job? = null

    fun start(scope: CoroutineScope): Boolean {
        if (wakeWordEngine != null) return true

        if (ContextCompat.checkSelfPermission(context, android.Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "RECORD_AUDIO permission not granted; cannot start voice detection")
            return false
        }

        return try {
            val model = WakeWordModel(MODEL_NAME, MODEL_FILE, THRESHOLD)
            val engine = WakeWordEngine(
                context = context.applicationContext,
                models = listOf(model),
                detectionMode = DetectionMode.SINGLE_BEST,
            )
            wakeWordEngine = engine
            engine.start()

            voiceJob = scope.launch {
                try {
                    engine.detections.collect { detection ->
                        Log.d(TAG, "🚨 Wake word '${detection.model.name}' detected! (score=${detection.score})")
                        onVoiceTriggered()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Voice detection flow error", e)
                }
            }
            Log.d(TAG, "Voice detection started for '$MODEL_NAME'")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize WakeWordEngine", e)
            wakeWordEngine = null
            false
        }
    }

    fun stop() {
        voiceJob?.cancel()
        voiceJob = null
        try {
            wakeWordEngine?.stop()
            wakeWordEngine?.release()
            Log.d(TAG, "Voice detection stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping WakeWordEngine", e)
        }
        wakeWordEngine = null
    }

    fun isRunning(): Boolean = wakeWordEngine != null
}
