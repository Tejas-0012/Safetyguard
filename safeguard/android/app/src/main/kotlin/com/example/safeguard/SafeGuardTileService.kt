package com.example.safeguard

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.telephony.SmsManager
import android.util.Log
import androidx.annotation.RequiresApi
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

@RequiresApi(Build.VERSION_CODES.N)
class SafeGuardTileService : TileService() {

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    companion object {
        private const val TAG = "SafeGuardTile"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_TOKEN = "flutter.safeguard_auth_token"
        private const val KEY_USER_NAME = "flutter.safeguard_user_name"
        private const val KEY_LAST_LAT = "flutter.safeguard_last_lat"
        private const val KEY_LAST_LNG = "flutter.safeguard_last_lng"
        private const val KEY_API_BASE = "flutter.safeguard_api_base_url"
        private const val KEY_EMERGENCY_ID = "flutter.safeguard_emergency_id"
        private const val KEY_EMERGENCY_ACTIVE = "flutter.safeguard_emergency_active"
    }

    override fun onStartListening() {
        super.onStartListening()
        updateTile()
    }

    override fun onTileAdded() {
        super.onTileAdded()
        updateTile()
    }

    private fun updateTile() {
        val tile = qsTile ?: return
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        val token = prefs.getString(KEY_TOKEN, null)

        if (token.isNullOrEmpty()) {
            tile.state = Tile.STATE_UNAVAILABLE
            tile.label = "SafeGuard (Login first)"
            tile.subtitle = "Open app to login"
        } else {
            tile.state = Tile.STATE_INACTIVE
            tile.label = "SafeGuard SOS"
            tile.subtitle = "Tap to send SOS"
        }
        tile.updateTile()
    }

    override fun onClick() {
        super.onClick()
        Log.d(TAG, "Tile clicked — triggering SOS")

        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        val token = prefs.getString(KEY_TOKEN, null)

        if (token.isNullOrEmpty()) {
            Log.w(TAG, "No auth token — opening app")
            openApp()
            return
        }

        val tile = qsTile
        tile?.state = Tile.STATE_ACTIVE
        tile?.subtitle = "Sending SOS..."
        tile?.updateTile()

        scope.launch {
            try {
                triggerSos(prefs, token)
                withContextMain {
                    tile?.subtitle = "SOS SENT"
                    tile?.updateTile()
                }
            } catch (e: Exception) {
                Log.e(TAG, "SOS trigger failed", e)
                withContextMain {
                    tile?.state = Tile.STATE_INACTIVE
                    tile?.subtitle = "Failed — tap to retry"
                    tile?.updateTile()
                }
            }
        }
    }

    private suspend fun triggerSos(prefs: SharedPreferences, token: String) {
        val lat = extractDouble(prefs.getString(KEY_LAST_LAT, null))
            ?.takeIf { it != 0.0 }
        val lng = extractDouble(prefs.getString(KEY_LAST_LNG, null))
            ?.takeIf { it != 0.0 }

        if (lat == null || lng == null) {
            Log.w(TAG, "No last known location — opening app")
            openApp()
            return
        }

        val apiBase = prefs.getString(KEY_API_BASE, null)
            ?: "https://safetyguard-fcn6.onrender.com/api"

        Log.d(TAG, "Starting emergency at $lat,$lng via $apiBase")

        val (emergencyId, links) = startEmergencyApi(apiBase, token, lat, lng)
        if (emergencyId == null) {
            Log.e(TAG, "Failed to create emergency")
            return
        }

        val userName = prefs.getString(KEY_USER_NAME, "User") ?: "User"
        val sentCount = sendPersonalizedSms(links, userName)
        Log.d(TAG, "SOS triggered. Sent $sentCount/${links.size} SMS")

        // Persist emergency id + start background capture (app does NOT open)
        prefs.edit()
            .putString(KEY_EMERGENCY_ID, emergencyId)
            .putBoolean(KEY_EMERGENCY_ACTIVE, true)
            .apply()

        ShakeDetectionService.startEmergencyMode(this)
        Log.d(TAG, "🚨 Background capture started")
    }

    // ============ API CALLS ============

    private fun startEmergencyApi(
        apiBase: String,
        token: String,
        lat: Double,
        lng: Double,
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
                Log.d(TAG, "✅ SMS sent to ${link.contactName}")
            } catch (e: Exception) {
                Log.e(TAG, "❌ SMS failed to ${link.contactName}", e)
            }
        }
        return sentCount
    }

    private fun normalizePhone(phone: String): String {
        var cleaned = phone.replace(Regex("[^0-9]"), "")
        if (cleaned.startsWith("0")) cleaned = cleaned.substring(1)
        return if (!cleaned.startsWith("91")) "+91$cleaned" else "+$cleaned"
    }

    private fun extractDouble(raw: String?): Double? {
        if (raw.isNullOrEmpty()) return null
        raw.toDoubleOrNull()?.let { return it }
        val matches = Regex("""-?\d+\.?\d*""").findAll(raw).toList()
        return matches.lastOrNull()?.value?.toDoubleOrNull()
    }

    private fun openApp() {
        try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            intent?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("from_tile", true)
            }
            if (intent != null) {
                startActivityAndCollapse(
                    PendingIntent.getActivity(
                        this, 0, intent,
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                    ),
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open app", e)
        }
    }

    private suspend fun withContextMain(block: () -> Unit) {
        android.os.Handler(mainLooper).post(block)
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
    }
}