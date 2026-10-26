package com.example.safeguard
import com.rementia.openwakeword.lib.WakeWordEngine
import com.rementia.openwakeword.lib.model.WakeWordModel
import com.rementia.openwakeword.lib.model.DetectionMode
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
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
import kotlin.math.sqrt

data class ReceiverLink(
    val contactName: String,
    val contactPhone: String,
    val webUrl: String,
    val token: String,
)

class ShakeDetectionService : LifecycleService(), SensorEventListener {

    companion object {
        private const val TAG = "ShakeService"
        private const val CHANNEL_ID = "safeguard_monitoring"
        private const val NOTIFICATION_ID = 9001

        private var audioRecorder: AudioRecorder? = null
        private var cameraCapture: CameraCapture? = null

        const val ACTION_START_SHAKE = "com.example.safeguard.SHAKE_START"
        const val ACTION_STOP_SHAKE = "com.example.safeguard.SHAKE_STOP"
        const val ACTION_START_EMERGENCY = "com.example.safeguard.EMERGENCY_START"
        const val ACTION_STOP_EMERGENCY = "com.example.safeguard.EMERGENCY_STOP"

        private const val SHAKE_THRESHOLD_G = 2.5f
        private const val SHAKE_COUNT_REQUIRED = 3
        private const val SHAKE_WINDOW_MS = 2000L
        private const val MIN_INTERVAL_MS = 200L
        private const val COOLDOWN_MS = 30000L

        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_TOKEN = "flutter.safeguard_auth_token"
        private const val KEY_USER_NAME = "flutter.safeguard_user_name"
        private const val KEY_LAST_LAT = "flutter.safeguard_last_lat"
        private const val KEY_LAST_LNG = "flutter.safeguard_last_lng"
        private const val KEY_API_BASE = "flutter.safeguard_api_base_url"
        private const val KEY_EMERGENCY_ACTIVE = "flutter.safeguard_emergency_active"
        private const val KEY_EMERGENCY_ID = "flutter.safeguard_emergency_id"

        fun startShakeDetection(context: Context) {
            val intent = Intent(context, ShakeDetectionService::class.java).apply {
                action = ACTION_START_SHAKE
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopShakeDetection(context: Context) {
            val intent = Intent(context, ShakeDetectionService::class.java).apply {
                action = ACTION_STOP_SHAKE
            }
            context.startService(intent)
        }

        fun startEmergencyMode(context: Context) {
            val intent = Intent(context, ShakeDetectionService::class.java).apply {
                action = ACTION_START_EMERGENCY
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopEmergencyMode(context: Context) {
            val intent = Intent(context, ShakeDetectionService::class.java).apply {
                action = ACTION_STOP_EMERGENCY
            }
            context.startService(intent)
        }
    }

    private lateinit var sensorManager: SensorManager
    private var accelerometer: Sensor? = null

    private var isServiceRunning = false
    private var isShakeEnabled = false
    private var isEmergencyActive = false

    private var shakeCount = 0
    private var firstShakeTime = 0L
    private var lastShakeTime = 0L

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onCreate() {
        super.onCreate()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)

        when (intent?.action) {
            ACTION_START_SHAKE -> {
                enableShakeDetection()
                startVoiceDetection()
                ensureForegroundService()
                
            }
            ACTION_STOP_SHAKE -> {
                disableShakeDetection()
                stopVoiceDetection()
                if (!isEmergencyActive) stopEverything()
            }
            ACTION_START_EMERGENCY -> {
                isEmergencyActive = true
                persistEmergencyFlag(true)
                ensureForegroundService()
                updateNotification()
                startEvidenceCapture()
            }
            ACTION_STOP_EMERGENCY -> {
                isEmergencyActive = false
                persistEmergencyFlag(false)
                stopEvidenceCapture()
                if (!isShakeEnabled) {
                    stopEverything()
                } else {
                    updateNotification()
                }
            }
        }
        return START_STICKY
    }

private var wakeWordEngine: WakeWordEngine? = null
private var voiceJob: kotlinx.coroutines.Job? = null
@Volatile private var lastTriggerTime = 0L

private fun startVoiceDetection() {
    if (wakeWordEngine != null) return
    if (checkSelfPermission(android.Manifest.permission.RECORD_AUDIO)
        != android.content.pm.PackageManager.PERMISSION_GRANTED) {
        Log.w(TAG, "No RECORD_AUDIO, skipping voice detection")
        return
    }
    try {
        val model = WakeWordModel("code_red", "code_red.onnx", 0.7f)
        val engine = WakeWordEngine(
            applicationContext,
            listOf(model),
            DetectionMode.SINGLE_BEST
        )
        wakeWordEngine = engine
        engine.start()

        voiceJob = scope.launch {
            engine.detections.collect { d ->
                val now = System.currentTimeMillis()
                if (isEmergencyActive || now - lastTriggerTime < COOLDOWN_MS) return@collect
                lastTriggerTime = now
                Log.d(TAG, "Wake word 'code red' (score=${d.score})")
                triggerSosFromShake("voice")
            }
        }
        Log.d(TAG, "Voice detection started")
    } catch (e: Exception) {
        Log.e(TAG, "Voice detection failed to start", e)
        wakeWordEngine = null
    }
}

private fun stopVoiceDetection() {
    voiceJob?.cancel(); voiceJob = null
    try {
        wakeWordEngine?.stop()
        wakeWordEngine?.release()
    } catch (e: Exception) {
        Log.e(TAG, "Wake word stop error", e)
    }
    wakeWordEngine = null
}

    // ============ EVIDENCE CAPTURE ============

    private fun startEvidenceCapture() {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val token = prefs.getString(KEY_TOKEN, null)
            val apiBase = prefs.getString(KEY_API_BASE, null)
                ?: "https://safetyguard-fcn6.onrender.com/api"

            if (token.isNullOrEmpty()) {
                Log.w(TAG, "Cannot start evidence: no token")
                return
            }

            val emergencyId = prefs.getString(KEY_EMERGENCY_ID, null)
            if (emergencyId.isNullOrEmpty()) {
                Log.w(TAG, "Cannot start evidence: no emergency ID")
                return
            }

            if (audioRecorder == null) {
                audioRecorder = AudioRecorder(applicationContext, apiBase, token, emergencyId).also {
                    it.start()
                    Log.d(TAG, "🎙️ Native audio recorder started")
                }
            }

            if (cameraCapture == null) {
                cameraCapture = CameraCapture(this, apiBase, token, emergencyId).also {
                    it.start()
                    Log.d(TAG, "📸 Native camera capture started")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start evidence capture", e)
        }
    }

    private fun stopEvidenceCapture() {
        try {
            audioRecorder?.stop()
            audioRecorder = null
            Log.d(TAG, "🛑 Native audio recorder stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Audio stop error", e)
        }

        try {
            cameraCapture?.stop()
            cameraCapture = null
            Log.d(TAG, "🛑 Native camera capture stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Camera stop error", e)
        }
    }

    // ============ FOREGROUND SERVICE ============

    private fun ensureForegroundService() {
        if (!isServiceRunning) {
            isServiceRunning = true
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    buildNotification(),
                    android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE or
                    android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA or
                    android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
                )
            } else {
                startForeground(NOTIFICATION_ID, buildNotification())
            }
            Log.d(TAG, "✅ Foreground service started")
        } else {
            updateNotification()
        }
    }

    private fun stopEverything() {
        if (!isServiceRunning) return

        sensorManager.unregisterListener(this)
        isServiceRunning = false
        isShakeEnabled = false
        isEmergencyActive = false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
        Log.d(TAG, "🛑 Service stopped")
    }

    // ============ SHAKE DETECTION ============

    private fun enableShakeDetection() {
        if (isShakeEnabled) return
        isShakeEnabled = true
        accelerometer?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
            Log.d(TAG, "✅ Shake detection enabled")
        } ?: Log.e(TAG, "❌ No accelerometer")
    }

    private fun disableShakeDetection() {
        if (!isShakeEnabled) return
        isShakeEnabled = false
        sensorManager.unregisterListener(this)
        Log.d(TAG, "🛑 Shake detection disabled")
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || event.sensor.type != Sensor.TYPE_ACCELEROMETER) return
        if (!isShakeEnabled) return

        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]
        val gForce = sqrt(x * x + y * y + z * z) / SensorManager.GRAVITY_EARTH

        val now = System.currentTimeMillis()
        if (now - lastTriggerTime < COOLDOWN_MS) return

        if (gForce > SHAKE_THRESHOLD_G) {
            if (now - lastShakeTime < MIN_INTERVAL_MS) return
            lastShakeTime = now

            if (shakeCount == 0 || now - firstShakeTime > SHAKE_WINDOW_MS) {
                shakeCount = 1
                firstShakeTime = now
                Log.d(TAG, "Shake 1 detected (gForce=$gForce)")
            } else {
                shakeCount++
                Log.d(TAG, "Shake $shakeCount detected (gForce=$gForce)")
                if (shakeCount >= SHAKE_COUNT_REQUIRED) {
                    Log.d(TAG, "🚨 SHAKE PATTERN DETECTED")
                    shakeCount = 0
                    lastTriggerTime = now
                    triggerSosFromShake()
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    // ============ SOS TRIGGER ============

    private fun triggerSosFromShake(source: String = "shake") {
        scope.launch {
            try {
                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val token = prefs.getString(KEY_TOKEN, null) ?: return@launch
                val lat = extractDouble(prefs.getString(KEY_LAST_LAT, null)) ?: return@launch
                val lng = extractDouble(prefs.getString(KEY_LAST_LNG, null)) ?: return@launch
                val apiBase = prefs.getString(KEY_API_BASE, null)
                    ?: "https://safetyguard-fcn6.onrender.com/api"

                val (emergencyId, links) = startEmergencyApi(apiBase, token, lat, lng,"shake")
                if (emergencyId == null) return@launch

                val userName = prefs.getString(KEY_USER_NAME, "User") ?: "User"
                val sentCount = sendPersonalizedSms(links, userName)
                Log.d(TAG, "SOS triggered. Sent $sentCount/${links.size} SMS")

                prefs.edit()
                    .putString(KEY_EMERGENCY_ID, emergencyId)
                    .putBoolean(KEY_EMERGENCY_ACTIVE, true)
                    .apply()

                isEmergencyActive = true
                updateNotificationFromMain()
                startEvidenceCapture()
            } catch (e: Exception) {
                Log.e(TAG, "SOS trigger failed", e)
            }
        }
    }

    // ============ NOTIFICATION ============

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SafeGuard Monitoring",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Keeps SafeGuard features active"
                setShowBadge(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }

        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pi = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val title: String
        val text: String
        if (isEmergencyActive) {
            title = "🚨 SafeGuard EMERGENCY"
            text = "Recording audio & sharing location"
        } else if (isShakeEnabled) {
            title = "SafeGuard is Active"
            text = "Shake phone 3 times to send SOS"
        } else {
            title = "SafeGuard"
            text = "Monitoring active"
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pi)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateNotification() {
        if (isServiceRunning) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIFICATION_ID, buildNotification())
        }
    }

    private fun updateNotificationFromMain() {
        android.os.Handler(mainLooper).post { updateNotification() }
    }

    // ============ HELPERS ============

    private fun persistEmergencyFlag(active: Boolean) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_EMERGENCY_ACTIVE, active).apply()
    }

    private fun normalizePhone(phone: String): String {
        var cleaned = phone.replace(Regex("[^0-9]"), "")
        if (cleaned.startsWith("0")) cleaned = cleaned.substring(1)
        return if (!cleaned.startsWith("91")) "+91$cleaned" else "+$cleaned"
    }

    private fun extractDouble(raw: String?): Double? {
        if (raw.isNullOrEmpty()) return null
        raw.toDoubleOrNull()?.let { return it }
        return Regex("""-?\d+\.?\d*""").findAll(raw).lastOrNull()?.value?.toDoubleOrNull()
    }

    // ============ API CALLS ============

    private fun startEmergencyApi(
        apiBase: String,
        token: String,
        lat: Double,
        lng: Double,
        triggerSource: String,
    ): Pair<String?, List<ReceiverLink>> {
        return try {
            val url = URL("$apiBase/emergency/start")
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
                put("triggerSource",triggerSource)
            }
            OutputStreamWriter(conn.outputStream).use { it.write(body.toString()) }

            val code = conn.responseCode
            val respText = if (code in 200..299) {
                conn.inputStream.bufferedReader().readText()
            } else {
                conn.errorStream?.bufferedReader()?.readText() ?: ""
            }

            Log.d(TAG, "startEmergency [$code]: $respText")

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

    private fun sendPersonalizedSms(
        links: List<ReceiverLink>,
        userName: String,
    ): Int {
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
                    null,
                )
                sentCount++
            } catch (e: Exception) {
                Log.e(TAG, "SMS failed to ${link.contactName}", e)
            }
        }
        return sentCount
    }

    override fun onBind(intent: Intent): IBinder? {
        super.onBind(intent)
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        sensorManager.unregisterListener(this)
        stopEvidenceCapture()
        scope.cancel()
    }
}