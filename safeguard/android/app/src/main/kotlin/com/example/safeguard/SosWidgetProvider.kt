package com.example.safeguard

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.telephony.SmsManager
import android.util.Log
import android.widget.RemoteViews
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
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
        private const val KEY_EMERGENCY_ID = "flutter.safeguard_emergency_id"
        private const val KEY_EMERGENCY_ACTIVE = "flutter.safeguard_emergency_active"

        const val ACTION_SOS_TAP = "com.example.safeguard.SOS_WIDGET_TAP"

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
        } else {
            views.setTextViewText(R.id.widget_title, "SOS")
            views.setTextViewText(R.id.widget_subtitle, "Tap to send alert")
            views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_bg)
        }

        val tapIntent = Intent(context, SosWidgetProvider::class.java).apply {
            action = ACTION_SOS_TAP
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, 0, tapIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

        manager.updateAppWidget(widgetId, views)
    }

    private fun triggerSos(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val token = prefs.getString(KEY_TOKEN, null)

        if (token.isNullOrEmpty()) {
            Log.w(TAG, "No auth token — opening app")
            openApp(context)
            return
        }

        updateWidgetStatus(context, "SENDING...", "Please wait")

        scope.launch {
            try {
                val success = doTriggerSos(context, prefs, token)
                if (success) {
                    updateWidgetStatus(context, "SOS SENT", "Recording started")
                    Thread.sleep(4000)
                    updateWidgetStatus(context, "SOS", "Tap to send alert")
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

        val (emergencyId, links) = startEmergencyApi(apiBase, token, lat, lng,"widget")
        if (emergencyId == null) {
            Log.e(TAG, "Failed to create emergency")
            return false
        }

        val userName = prefs.getString(KEY_USER_NAME, "User") ?: "User"
        val sentCount = sendPersonalizedSms(context, links, userName)
        Log.d(TAG, "SOS triggered. Sent $sentCount/${links.size} SMS")

        prefs.edit()
            .putString(KEY_EMERGENCY_ID, emergencyId)
            .putBoolean(KEY_EMERGENCY_ACTIVE, true)
            .apply()

        ShakeDetectionService.startEmergencyMode(context,"widget")
        Log.d(TAG, "🚨 Background capture started")

        return true
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
                put("triggerSource", triggerSource)
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
        context: Context,
        links: List<ReceiverLink>,
        userName: String,
    ): Int {
        if (links.isEmpty()) return 0

        val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(SmsManager::class.java)
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
                Log.d(TAG, "✅ SMS sent to ${link.contactName}")
            } catch (e: Exception) {
                Log.e(TAG, "❌ SMS failed to ${link.contactName}", e)
            }
        }
        return sentCount
    }

    private fun updateWidgetStatus(context: Context, title: String, subtitle: String) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, SosWidgetProvider::class.java)
        )
        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.sos_widget)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_subtitle, subtitle)

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
                putExtra("from_tile", true)
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