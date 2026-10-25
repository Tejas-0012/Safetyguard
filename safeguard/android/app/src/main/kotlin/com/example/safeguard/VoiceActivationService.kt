package com.example.safeguard

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.rementia.openwakeword.lib.WakeWordEngine
import com.rementia.openwakeword.lib.model.DetectionMode
import com.rementia.openwakeword.lib.model.WakeWordModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class VoiceActivationService : Service() {

    companion object {
        private const val TAG = "VoiceService"
        private const val CHANNEL_ID = "safeguard_voice"
        private const val NOTIFICATION_ID = 9003
        private const val COOLDOWN_MS = 30000L

        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_TOKEN = "flutter.safeguard_auth_token"
        private const val KEY_LAST_LAT = "flutter.safeguard_last_lat"
        private const val KEY_LAST_LNG = "flutter.safeguard_last_lng"
        private const val KEY_API_BASE = "flutter.safeguard_api_base_url"

        fun start(context: Context) {
            Log.d("VoiceService", "🚀 start() function called!")
            val intent = Intent(context, VoiceActivationService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, VoiceActivationService::class.java))
        }
    }

    private var wakeWordEngine: WakeWordEngine? = null
    private var voiceJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    @Volatile private var lastTriggerTime = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
         Log.d("VoiceService", "▶️ onStartCommand triggered")
        
        try {
        startForegroundNotification()
        Log.d("VoiceService", "✅ Foreground notification started")

         startVoiceDetection()
    } catch (e: Exception) {
        Log.e("VoiceService", "❌ CRASH in onStartCommand: ${e.message}")
         }
    return START_STICKY
}
       
    private fun startForegroundNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "SafeGuard Voice AI", NotificationManager.IMPORTANCE_LOW
            )
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pi = PendingIntent.getActivity(this, 0, openAppIntent, PendingIntent.FLAG_IMMUTABLE)

        val notif = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SafeGuard Voice Active")
            .setContentText("Listening for 'Activate SafeGuard'")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()

        startForeground(NOTIFICATION_ID, notif)
    }

    private fun startVoiceDetection() {
        if (wakeWordEngine != null) return
        if (checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "No RECORD_AUDIO permission")
            return
        }

        try {
            val model = WakeWordModel("code_red", "code_red.onnx", 0.5f)
            val engine = WakeWordEngine(applicationContext, listOf(model), DetectionMode.SINGLE_BEST)
            wakeWordEngine = engine
            engine.start()

            voiceJob = scope.launch {
                engine.detections.collect { d ->
                    val now = System.currentTimeMillis()
                    if (now - lastTriggerTime < COOLDOWN_MS) return@collect
                    lastTriggerTime = now
                    
                    Log.d(TAG, "🚨 Wake word detected! Score: ${d.score}")
                    
                    // Stop listening so we don't trigger twice
                    stopVoiceDetection()
                    
                    // Trigger the SOS
                    triggerSos()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start voice detection", e)
        }
    }

    private fun stopVoiceDetection() {
        voiceJob?.cancel(); voiceJob = null
        try {
            wakeWordEngine?.stop()
            wakeWordEngine?.release()
        } catch (_: Exception) {}
        wakeWordEngine = null
    }

    private fun triggerSos() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val token = prefs.getString(KEY_TOKEN, null) ?: return
        val lat = extractDouble(prefs.getString(KEY_LAST_LAT, null)) ?: return
        val lng = extractDouble(prefs.getString(KEY_LAST_LNG, null)) ?: return
        val apiBase = prefs.getString(KEY_API_BASE, null) ?: "https://safetyguard-fcn6.onrender.com/api"

        scope.launch {
            val api = EmergencyApiClient(apiBase, token)
            val result = api.startEmergency(lat, lng, "voice")
            
            if (result != null) {
                val (emergencyId, links) = result
                prefs.edit()
                    .putString("flutter.safeguard_emergency_id", emergencyId)
                    .putBoolean("flutter.safeguard_emergency_active", true)
                    .apply()

                api.sendSms(links, prefs.getString("flutter.safeguard_user_name", "User") ?: "User")
                
                // Start the evidence service
                ShakeDetectionService.startEmergencyMode(this@VoiceActivationService, "voice")
            }
            stopSelf() // Stop voice service after trigger
        }
    }

    private fun extractDouble(raw: String?): Double? {
        if (raw.isNullOrEmpty()) return null
        raw.toDoubleOrNull()?.let { return it }
        return Regex("""-?\d+\.?\d*""").findAll(raw).lastOrNull()?.value?.toDoubleOrNull()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopVoiceDetection()
        scope.cancel()
    }
}