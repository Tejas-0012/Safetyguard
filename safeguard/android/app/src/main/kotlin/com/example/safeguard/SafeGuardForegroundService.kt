package com.example.safeguard

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.telephony.SmsManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.lifecycle.LifecycleService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

class SafeGuardForegroundService : LifecycleService() {

    companion object {
        private const val TAG = "SafeGuardFGS"
        private const val CHANNEL_ID = "safeguard_monitoring"
        private const val NOTIFICATION_ID = 9001

        const val ACTION_ENABLE_SHAKE = "com.example.safeguard.ACTION_ENABLE_SHAKE"
        const val ACTION_DISABLE_SHAKE = "com.example.safeguard.ACTION_DISABLE_SHAKE"
        const val ACTION_ENABLE_VOICE = "com.example.safeguard.ACTION_ENABLE_VOICE"
        const val ACTION_DISABLE_VOICE = "com.example.safeguard.ACTION_DISABLE_VOICE"
        const val ACTION_START_EMERGENCY = "com.example.safeguard.ACTION_START_EMERGENCY"
        const val ACTION_STOP_EMERGENCY = "com.example.safeguard.ACTION_STOP_EMERGENCY"

        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_SHAKE_ENABLED = "flutter.safeguard_shake_enabled"
        private const val KEY_VOICE_ENABLED = "flutter.safeguard_voice_enabled"
        private const val KEY_EMERGENCY_ACTIVE = "flutter.safeguard_emergency_active"
        private const val KEY_EMERGENCY_ID = "flutter.safeguard_emergency_id"
        private const val KEY_TOKEN = "flutter.safeguard_auth_token"
        private const val KEY_USER_NAME = "flutter.safeguard_user_name"
        private const val KEY_LAST_LAT = "flutter.safeguard_last_lat"
        private const val KEY_LAST_LNG = "flutter.safeguard_last_lng"
        private const val KEY_API_BASE = "flutter.safeguard_api_base_url"

        private var audioRecorder: AudioRecorder? = null
        private var liveKitManager: LiveKitManager? = null

        fun enableShake(context: Context, enabled: Boolean) {
            val intent = Intent(context, SafeGuardForegroundService::class.java).apply {
                action = if (enabled) ACTION_ENABLE_SHAKE else ACTION_DISABLE_SHAKE
            }
            startServiceIntent(context, intent)
        }

        fun enableVoice(context: Context, enabled: Boolean) {
            val intent = Intent(context, SafeGuardForegroundService::class.java).apply {
                action = if (enabled) ACTION_ENABLE_VOICE else ACTION_DISABLE_VOICE
            }
            startServiceIntent(context, intent)
        }

        fun startEmergency(context: Context) {
            val intent = Intent(context, SafeGuardForegroundService::class.java).apply {
                action = ACTION_START_EMERGENCY
            }
            startServiceIntent(context, intent)
        }

        fun stopEmergency(context: Context) {
            val intent = Intent(context, SafeGuardForegroundService::class.java).apply {
                action = ACTION_STOP_EMERGENCY
            }
            startServiceIntent(context, intent)
        }

        private fun startServiceIntent(context: Context, intent: Intent) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private lateinit var sensorManager: SensorManager

    private var shakeDetector: ShakeDetector? = null
    private var voiceDetector: VoiceDetector? = null

    private var isServiceRunning = false
    private var isShakeEnabled = false
    private var isVoiceEnabled = false
    private var isEmergencyActive = false

    override fun onCreate() {
        super.onCreate()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager

        // Instantiate decoupled detectors with trigger callbacks
        shakeDetector = ShakeDetector {
            Log.d(TAG, "🚨 Shake triggered -> starting SOS")
            handleTrigger("shake")
        }

        voiceDetector = VoiceDetector(applicationContext) {
            Log.d(TAG, "🚨 Voice triggered -> starting SOS")
            handleTrigger("voice")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        val action = intent?.action ?: return START_STICKY
        Log.d(TAG, "onStartCommand action: $action")

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        isShakeEnabled = prefs.getBoolean(KEY_SHAKE_ENABLED, false)
        isVoiceEnabled = prefs.getBoolean(KEY_VOICE_ENABLED, false)
        isEmergencyActive = prefs.getBoolean(KEY_EMERGENCY_ACTIVE, false)

        when (action) {
            ACTION_ENABLE_SHAKE -> {
                isShakeEnabled = true
                prefs.edit().putBoolean(KEY_SHAKE_ENABLED, true).apply()
                shakeDetector?.start(sensorManager)
                ensureForeground()
            }
            ACTION_DISABLE_SHAKE -> {
                isShakeEnabled = false
                prefs.edit().putBoolean(KEY_SHAKE_ENABLED, false).apply()
                shakeDetector?.stop(sensorManager)
                checkIfShouldStopService()
            }
            ACTION_ENABLE_VOICE -> {
                isVoiceEnabled = true
                prefs.edit().putBoolean(KEY_VOICE_ENABLED, true).apply()
                voiceDetector?.start(scope)
                ensureForeground()
            }
            ACTION_DISABLE_VOICE -> {
                isVoiceEnabled = false
                prefs.edit().putBoolean(KEY_VOICE_ENABLED, false).apply()
                voiceDetector?.stop()
                checkIfShouldStopService()
            }
            ACTION_START_EMERGENCY -> {
                isEmergencyActive = true
                prefs.edit().putBoolean(KEY_EMERGENCY_ACTIVE, true).apply()
                ensureForeground()
                startEvidenceStreaming()
            }
            ACTION_STOP_EMERGENCY -> {
                stopEmergencyMode()
            }
        }

        return START_STICKY
    }

    private fun checkIfShouldStopService() {
        if (!isShakeEnabled && !isVoiceEnabled && !isEmergencyActive) {
            stopEverything()
        } else {
            updateNotification()
        }
    }

    private fun ensureForeground() {
        if (!isServiceRunning) {
            isServiceRunning = true
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    buildNotification(),
                    android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE or
                    android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA or
                    android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                )
            } else {
                startForeground(NOTIFICATION_ID, buildNotification())
            }
        } else {
            updateNotification()
        }
    }

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SafeGuard Protection",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Keeps SafeGuard emergency features active in background"
                setShowBadge(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }

        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("from_notification", true)
            if (isEmergencyActive) putExtra("openEmergencyMode", true)
        }
        val contentPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(contentPendingIntent)
            .setOngoing(true)

        if (isEmergencyActive) {
            // EMERGENCY STATE WITH STOP BUTTON
            builder.setContentTitle("🚨 SafeGuard EMERGENCY ACTIVE")
                .setContentText("Streaming live camera & sharing location")
                .setPriority(NotificationCompat.PRIORITY_MAX)

            // 🛑 STOP EMERGENCY ACTION BUTTON IN NOTIFICATION
            val stopIntent = Intent(this, SafeGuardForegroundService::class.java).apply {
                action = ACTION_STOP_EMERGENCY
            }
            val stopPendingIntent = PendingIntent.getService(
                this,
                1001,
                stopIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            builder.addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "🛑 STOP EMERGENCY",
                stopPendingIntent
            )
        } else {
            val text = when {
                isShakeEnabled && isVoiceEnabled -> "Shake 3x or say 'Code Red' to trigger SOS"
                isShakeEnabled -> "Shake phone 3 times to send SOS"
                isVoiceEnabled -> "Say 'Code Red' to trigger hands-free SOS"
                else -> "SafeGuard monitoring is active"
            }
            builder.setContentTitle("SafeGuard is Active")
                .setContentText(text)
                .setPriority(NotificationCompat.PRIORITY_LOW)
        }

        return builder.build()
    }

    private fun updateNotification() {
        if (isServiceRunning) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIFICATION_ID, buildNotification())
        }
    }

    // ============ EMERGENCY HANDLING ============

    private fun handleTrigger(source: String) {
        scope.launch {
            try {
                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val token = prefs.getString(KEY_TOKEN, null) ?: return@launch
                val lat = extractDouble(prefs.getString(KEY_LAST_LAT, null)) ?: return@launch
                val lng = extractDouble(prefs.getString(KEY_LAST_LNG, null)) ?: return@launch
                val apiBase = prefs.getString(KEY_API_BASE, "https://safetyguard-fcn6.onrender.com/api") ?: "https://safetyguard-fcn6.onrender.com/api"

                val (emergencyId, links) = startEmergencyApi(apiBase, token, lat, lng, source)
                if (emergencyId == null) return@launch

                prefs.edit()
                    .putBoolean(KEY_EMERGENCY_ACTIVE, true)
                    .putString(KEY_EMERGENCY_ID, emergencyId)
                    .apply()

                isEmergencyActive = true
                android.os.Handler(mainLooper).post {
                    ensureForeground()
                    startEvidenceStreaming()
                }

                val userName = prefs.getString(KEY_USER_NAME, "User") ?: "User"
                sendPersonalizedSms(links, userName)

                // Launch Flutter App to emergency screen
                val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("openEmergencyMode", true)
                }
                launchIntent?.let { startActivity(it) }

            } catch (e: Exception) {
                Log.e(TAG, "handleTrigger error", e)
            }
        }
    }

    private fun startEvidenceStreaming() {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val token = prefs.getString(KEY_TOKEN, null) ?: return
            val emergencyId = prefs.getString(KEY_EMERGENCY_ID, null) ?: return
            val apiBase = prefs.getString(KEY_API_BASE, "https://safetyguard-fcn6.onrender.com/api") ?: "https://safetyguard-fcn6.onrender.com/api"

            if (audioRecorder == null) {
                audioRecorder = AudioRecorder(applicationContext, apiBase, token, emergencyId).also {
                    it.start()
                    Log.d(TAG, "🎙️ AudioRecorder started")
                }
            }

            if (liveKitManager == null) {
                liveKitManager = LiveKitManager(applicationContext, this)
                liveKitManager?.startStreaming(emergencyId, token, apiBase)
                Log.d(TAG, "📹 LiveKit streaming started")
            }
        } catch (e: Exception) {
            Log.e(TAG, "startEvidenceStreaming error", e)
        }
    }

    private fun stopEmergencyMode() {
        Log.d(TAG, "🛑 Stopping emergency mode...")
        isEmergencyActive = false

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val token = prefs.getString(KEY_TOKEN, null)
        val emergencyId = prefs.getString(KEY_EMERGENCY_ID, null)
        val apiBase = prefs.getString(KEY_API_BASE, "https://safetyguard-fcn6.onrender.com/api") ?: "https://safetyguard-fcn6.onrender.com/api"

        prefs.edit().putBoolean(KEY_EMERGENCY_ACTIVE, false).apply()

        // 1. Stop streaming hardware
        try {
            audioRecorder?.stop()
            audioRecorder = null
            liveKitManager?.stopStreaming()
            liveKitManager = null
            Log.d(TAG, "Hardware streaming stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping hardware", e)
        }

        // 2. Call backend /stop API in background
        if (!token.isNullOrEmpty() && !emergencyId.isNullOrEmpty()) {
            scope.launch {
                try {
                    val cleanBase = apiBase.removeSuffix("/")
                    val url = URL("$cleanBase/emergency/$emergencyId/stop")
                    val conn = (url.openConnection() as HttpURLConnection).apply {
                        requestMethod = "POST"
                        setRequestProperty("Authorization", "Bearer $token")
                        connectTimeout = 10000
                        readTimeout = 10000
                    }
                    Log.d(TAG, "POST $url → ${conn.responseCode}")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to call emergency stop API", e)
                }
            }
        }

        // 3. Notify Flutter app so in-app UI immediately closes EmergencyModeScreen
        MainActivity.notifyEmergencyStopped()

        // 4. Update notification or stop service if both toggles off
        android.os.Handler(mainLooper).post {
            checkIfShouldStopService()
        }
    }

    private fun stopEverything() {
        if (!isServiceRunning) return
        isServiceRunning = false
        shakeDetector?.stop(sensorManager)
        voiceDetector?.stop()
        stopForeground(true)
        stopSelf()
        Log.d(TAG, "SafeGuardForegroundService stopped completely")
    }

    private fun extractDouble(raw: String?): Double? {
        if (raw.isNullOrEmpty()) return null
        raw.toDoubleOrNull()?.let { return it }
        return Regex("""-?\d+\.?\d*""").findAll(raw).lastOrNull()?.value?.toDoubleOrNull()
    }

    private fun startEmergencyApi(
        apiBase: String,
        token: String,
        lat: Double,
        lng: Double,
        triggerSource: String,
    ): Pair<String?, List<ReceiverLink>> {
        return try {
            val cleanBase = apiBase.removeSuffix("/")
            val url = URL("$cleanBase/emergency/start")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Authorization", "Bearer $token")
                doOutput = true
                connectTimeout = 15000
                readTimeout = 15000
            }

            val body = JSONObject().apply {
                put("latitude", lat)
                put("longitude", lng)
                put("triggerSource", triggerSource)
            }
            OutputStreamWriter(conn.outputStream).use { it.write(body.toString()) }

            val code = conn.responseCode
            val respText = if (code in 200..299) {
                conn.inputStream.bufferedReader().readText()
            } else {
                conn.errorStream?.bufferedReader()?.readText() ?: ""
            }

            if (code in 200..299) {
                val json = JSONObject(respText)
                val emergency = json.optJSONObject("emergency")
                val emergencyId = emergency?.optString("id")?.takeIf { it.isNotEmpty() }
                    ?: emergency?.optString("_id")?.takeIf { it.isNotEmpty() }

                val links = mutableListOf<ReceiverLink>()
                val linksArray = json.optJSONArray("receiverLinks")
                if (linksArray != null) {
                    for (i in 0 until linksArray.length()) {
                        val obj = linksArray.getJSONObject(i)
                        links.add(
                            ReceiverLink(
                                contactName = obj.optString("contactName", ""),
                                contactPhone = obj.optString("contactPhone", ""),
                                webUrl = obj.optString("webUrl", ""),
                                token = obj.optString("token", ""),
                            )
                        )
                    }
                }
                Pair(emergencyId, links)
            } else {
                Pair(null, emptyList())
            }
        } catch (e: Exception) {
            Log.e(TAG, "startEmergencyApi failed", e)
            Pair(null, emptyList())
        }
    }

    private fun sendPersonalizedSms(links: List<ReceiverLink>, userName: String): Int {
        if (links.isEmpty()) return 0
        val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }

        var sentCount = 0
        for (link in links) {
            if (link.contactPhone.isEmpty()) continue
            val message = "Hi ${link.contactName}, $userName has activated an SOS alert! " +
                    "Please help. Track live: ${link.webUrl}"
            try {
                smsManager.sendTextMessage(
                    normalizePhone(link.contactPhone),
                    null,
                    message,
                    null,
                    null
                )
                sentCount++
            } catch (e: Exception) {
                Log.e(TAG, "SMS failed to ${link.contactName}", e)
            }
        }
        return sentCount
    }

    private fun normalizePhone(phone: String): String {
        var cleaned = phone.replace(Regex("[^0-9]"), "")
        if (cleaned.startsWith("0")) cleaned = cleaned.substring(1)
        return if (!cleaned.startsWith("91")) "+91$cleaned" else "+$cleaned"
    }

    override fun onBind(intent: Intent): IBinder? {
        super.onBind(intent)
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        shakeDetector?.stop(sensorManager)
        voiceDetector?.stop()
        scope.cancel()
    }
}

