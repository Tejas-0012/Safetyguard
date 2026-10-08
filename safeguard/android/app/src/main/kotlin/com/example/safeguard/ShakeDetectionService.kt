package com.example.safeguard

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
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
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import kotlin.math.sqrt

class ShakeDetectionService : Service(), SensorEventListener {

    companion object {
        private const val TAG = "ShakeService"
        private const val CHANNEL_ID = "safeguard_monitoring"
        private const val NOTIFICATION_ID = 9001

        const val ACTION_START = "com.example.safeguard.SHAKE_START"
        const val ACTION_STOP = "com.example.safeguard.SHAKE_STOP"

        // Shake detection tuning
        private const val SHAKE_THRESHOLD_G = 2.5f      // Accel force threshold
        private const val SHAKE_COUNT_REQUIRED = 3       // Number of shakes
        private const val SHAKE_WINDOW_MS = 2000L        // 3 shakes within 2s
        private const val MIN_INTERVAL_MS = 200L         // Min time between shakes
        private const val COOLDOWN_MS = 30000L           // 30s cooldown after trigger

        // Same SharedPreferences keys as tile/widget
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_TOKEN = "flutter.safeguard_auth_token"
        private const val KEY_USER_NAME = "flutter.safeguard_user_name"
        private const val KEY_LAST_LAT = "flutter.safeguard_last_lat"
        private const val KEY_LAST_LNG = "flutter.safeguard_last_lng"
        private const val KEY_API_BASE = "flutter.safeguard_api_base_url"

        fun start(context: Context) {
            val intent = Intent(context, ShakeDetectionService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, ShakeDetectionService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private lateinit var sensorManager: SensorManager
    private var accelerometer: Sensor? = null
    private var isRunning = false

    // Shake detection state
    private var shakeCount = 0
    private var firstShakeTime = 0L
    private var lastShakeTime = 0L
    private var lastTriggerTime = 0L

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onCreate() {
        super.onCreate()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startMonitoring()
            ACTION_STOP -> stopMonitoring()
        }
        return START_STICKY
    }

    private fun startMonitoring() {
        if (isRunning) return
        isRunning = true

        // Start foreground with notification
       if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
    startForeground(
        NOTIFICATION_ID,
        buildNotification(),
        android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
    )
} else {
    startForeground(NOTIFICATION_ID, buildNotification())
}

        // Register accelerometer
        accelerometer?.let {
            sensorManager.registerListener(
                this,
                it,
                SensorManager.SENSOR_DELAY_GAME,
            )
            Log.d(TAG, "✅ Shake detection started")
        } ?: Log.e(TAG, "❌ No accelerometer available")

        // Persist flag
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean("flutter.safeguard_shake_enabled", true).apply()
    }

    private fun stopMonitoring() {
        if (!isRunning) return
        isRunning = false

        sensorManager.unregisterListener(this)
        stopForeground(true)
        stopSelf()

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean("flutter.safeguard_shake_enabled", false).apply()

        Log.d(TAG, "🛑 Shake detection stopped")
    }

    // ============ SENSOR EVENTS ============
    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || event.sensor.type != Sensor.TYPE_ACCELEROMETER) return
        if (!isRunning) return

        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]

        // Calculate g-force (excluding gravity)
        val gForce = sqrt(x * x + y * y + z * z) / SensorManager.GRAVITY_EARTH

        val now = System.currentTimeMillis()

        // Cooldown check
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
                    Log.d(TAG, "🚨 SHAKE PATTERN DETECTED — triggering SOS")
                    shakeCount = 0
                    lastTriggerTime = now
                    triggerSos()
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    // ============ SOS LOGIC ============
    private fun triggerSos() {
        scope.launch {
            try {
                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val token = prefs.getString(KEY_TOKEN, null)
                if (token.isNullOrEmpty()) {
                    Log.w(TAG, "No auth token — cannot trigger SOS")
                    return@launch
                }

                val lat = extractDouble(prefs.getString(KEY_LAST_LAT, null))
                    ?.takeIf { it != 0.0 }
                val lng = extractDouble(prefs.getString(KEY_LAST_LNG, null))
                    ?.takeIf { it != 0.0 }

                if (lat == null || lng == null) {
                    Log.w(TAG, "No last known location")
                    return@launch
                }

                val apiBase = prefs.getString(KEY_API_BASE, null)
                    ?: "https://safetyguard-fcn6.onrender.com/api"

                Log.d(TAG, "Starting emergency at $lat,$lng")

                // 1. Create emergency
                val emergencyId = startEmergencyApi(apiBase, token, lat, lng)
                    ?: return@launch

                // 2. Generate web link
                val webUrl = generateWebStreamApi(apiBase, token, emergencyId)

                // 3. Send SMS to contacts
                sendSmsToContacts(prefs, token, apiBase, lat, lng, webUrl)

                // 4. Open app to Emergency Mode
                openApp()
            } catch (e: Exception) {
                Log.e(TAG, "SOS trigger failed", e)
            }
        }
    }

    // ============ API CALLS ============
    private fun startEmergencyApi(
        apiBase: String,
        token: String,
        lat: Double,
        lng: Double,
    ): String? {
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
                val e = JSONObject(respText).optJSONObject("emergency")
                e?.optString("id")?.takeIf { it.isNotEmpty() }
                    ?: e?.optString("_id")?.takeIf { it.isNotEmpty() }
            } else null
        } catch (e: Exception) {
            Log.e(TAG, "startEmergencyApi failed", e)
            null
        }
    }

    private fun generateWebStreamApi(
        apiBase: String,
        token: String,
        emergencyId: String,
    ): String {
        return try {
            val url = URL("$apiBase/emergency/$emergencyId/web-stream")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Authorization", "Bearer $token")
                doOutput = true
                connectTimeout = 15000
                readTimeout = 15000
            }

            val code = conn.responseCode
            val respText = if (code in 200..299) {
                conn.inputStream.bufferedReader().readText()
            } else ""

            Log.d(TAG, "webStream [$code]: $respText")

            if (code in 200..299) JSONObject(respText).optString("webUrl", "") else ""
        } catch (e: Exception) {
            Log.e(TAG, "generateWebStreamApi failed", e)
            ""
        }
    }

    private fun sendSmsToContacts(
        prefs: SharedPreferences,
        token: String,
        apiBase: String,
        lat: Double,
        lng: Double,
        webUrl: String,
    ) {
        try {
            val url = URL("$apiBase/contacts")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                setRequestProperty("Authorization", "Bearer $token")
                connectTimeout = 15000
                readTimeout = 15000
            }

            val code = conn.responseCode
            if (code !in 200..299) return

            val respText = conn.inputStream.bufferedReader().readText()
            val contacts: JSONArray = JSONObject(respText).optJSONArray("contacts") ?: return

            val userName = prefs.getString(KEY_USER_NAME, "User") ?: "User"
            val message = if (webUrl.isNotEmpty()) {
                "EMERGENCY! $userName needs help. Track live: $webUrl"
            } else {
                "EMERGENCY! $userName needs help. Location: https://maps.google.com/?q=$lat,$lng"
            }

            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            for (i in 0 until contacts.length()) {
                val phone = contacts.getJSONObject(i).optString("phone", "")
                if (phone.isNotEmpty()) {
                    try {
                        smsManager.sendTextMessage(normalizePhone(phone), null, message, null, null)
                        Log.d(TAG, "SMS sent to $phone")
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed SMS to $phone", e)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "sendSmsToContacts failed", e)
        }
    }

    // ============ HELPERS ============
    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SafeGuard Monitoring",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Keeps shake detection active"
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

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SafeGuard is Active")
            .setContentText("Shake phone 3 times to trigger SOS")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pi)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun openApp() {
        try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            intent?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("from_tile", true)  // reuse flag → auto-navigate to Emergency Mode
            }
            if (intent != null) startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open app", e)
        }
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

    override fun onDestroy() {
        super.onDestroy()
        sensorManager.unregisterListener(this)
        scope.cancel()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}