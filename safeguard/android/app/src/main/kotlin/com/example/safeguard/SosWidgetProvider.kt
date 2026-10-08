package com.example.safeguard
import android.telephony.SmsManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.util.Log
import android.widget.RemoteViews
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

class SosWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "SosWidget"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_TOKEN = "flutter.safeguard_auth_token"
        private const val KEY_USER_NAME = "flutter.safeguard_user_name"
        private const val KEY_LAST_LAT = "flutter.safeguard_last_lat"
        private const val KEY_LAST_LNG = "flutter.safeguard_last_lng"
        private const val KEY_API_BASE = "flutter.safeguard_api_base_url"

        // Broadcast actions
        const val ACTION_SOS_TAP = "com.example.safeguard.SOS_WIDGET_TAP"

        /** Call this after every state change to refresh all widget instances */
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, SosWidgetProvider::class.java)
            )
            val intent = Intent(context, SosWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(intent)
        }
    }

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (widgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_SOS_TAP) {
            Log.d(TAG, "Widget tapped — triggering SOS")
            triggerSos(context)
        }
    }

    // ============ WIDGET UI UPDATE ============
    private fun updateWidget(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
    ) {
        val views = RemoteViews(context.packageName, R.layout.sos_widget)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val token = prefs.getString(KEY_TOKEN, null)

        if (token.isNullOrEmpty()) {
            views.setTextViewText(R.id.widget_title, "SOS")
            views.setTextViewText(R.id.widget_subtitle, "Login first")
            views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_bg)
            // Still clickable — will open app
        } else {
            views.setTextViewText(R.id.widget_title, "SOS")
            views.setTextViewText(R.id.widget_subtitle, "Tap to send alert")
            views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_bg)
        }

        // Tap handler → broadcast to this provider
        val tapIntent = Intent(context, SosWidgetProvider::class.java).apply {
            action = ACTION_SOS_TAP
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            tapIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

        manager.updateAppWidget(widgetId, views)
    }

    // ============ SOS LOGIC ============
    private fun triggerSos(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val token = prefs.getString(KEY_TOKEN, null)

        if (token.isNullOrEmpty()) {
            Log.w(TAG, "No auth token — opening app")
            openApp(context)
            return
        }

        // Show "Sending..." state
        updateWidgetStatus(context, "SENDING...", "Please wait")

        scope.launch {
            try {
                val success = doTriggerSos(context, prefs, token)
                if (success) {
                    updateWidgetStatus(context, "SOS SENT", "Opening app...")
                    // Reset to normal after 4 seconds
                    Thread.sleep(4000)
                    updateWidgetStatus(context, "SOS", "Tap to send alert")
                    openApp(context)
                } else {
                    updateWidgetStatus(context, "FAILED", "Tap to retry")
                    Thread.sleep(3000)
                    updateWidgetStatus(context, "SOS", "Tap to send alert")
                }
            } catch (e: Exception) {
                Log.e(TAG, "SOS trigger failed", e)
                updateWidgetStatus(context, "FAILED", "Tap to retry")
                Thread.sleep(3000)
                updateWidgetStatus(context, "SOS", "Tap to send alert")
            }
        }
    }

    private fun doTriggerSos(
        context: Context,
        prefs: SharedPreferences,
        token: String,
    ): Boolean {
        // 1. Read location
        val lat = extractDouble(prefs.getString(KEY_LAST_LAT, null))
            ?.takeIf { it != 0.0 }
        val lng = extractDouble(prefs.getString(KEY_LAST_LNG, null))
            ?.takeIf { it != 0.0 }

        if (lat == null || lng == null) {
            Log.w(TAG, "No last known location")
            return false
        }

        val apiBase = prefs.getString(KEY_API_BASE, null)
            ?: "https://safetyguard-fcn6.onrender.com/api"

        Log.d(TAG, "Starting emergency at $lat,$lng via $apiBase")

        // 2. Start emergency
        val emergencyId = startEmergencyApi(apiBase, token, lat, lng)
        if (emergencyId == null) {
            Log.e(TAG, "Failed to create emergency")
            return false
        }

        // 3. Generate web link
        val webUrl = generateWebStreamApi(apiBase, token, emergencyId)

        // 4. Send SMS to contacts
        sendSmsToContacts(context,prefs, token, apiBase, lat, lng, webUrl)

        return true
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

            Log.d(TAG, "startEmergency response [$code]: $respText")

            if (code in 200..299) {
                val emergency = JSONObject(respText).optJSONObject("emergency")
                emergency?.optString("id")?.takeIf { it.isNotEmpty() }
                    ?: emergency?.optString("_id")?.takeIf { it.isNotEmpty() }
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

            Log.d(TAG, "webStream response [$code]: $respText")

            if (code in 200..299) {
                JSONObject(respText).optString("webUrl", "")
            } else ""
        } catch (e: Exception) {
            Log.e(TAG, "generateWebStreamApi failed", e)
            ""
        }
    }

    private fun sendSmsToContacts(
        context: Context,
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
    context.getSystemService(SmsManager::class.java)
} else {
    @Suppress("DEPRECATION")
    android.telephony.SmsManager.getDefault()
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
    private fun updateWidgetStatus(context: Context, title: String, subtitle: String) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, SosWidgetProvider::class.java)
        )
        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.sos_widget)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_subtitle, subtitle)

            // Reattach click listener (must be re-applied on every update)
            val tapIntent = Intent(context, SosWidgetProvider::class.java).apply {
                action = ACTION_SOS_TAP
            }
            val pi = PendingIntent.getBroadcast(
                context, 0, tapIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            views.setOnClickPendingIntent(R.id.widget_root, pi)

            manager.updateAppWidget(id, views)
        }
    }

    private fun openApp(context: Context) {
        try {
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            intent?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("from_tile", true)  // reuse the tile flag
            }
            if (intent != null) context.startActivity(intent)
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

    
}