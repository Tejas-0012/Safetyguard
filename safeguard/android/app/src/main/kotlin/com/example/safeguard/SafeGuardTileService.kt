package com.example.safeguard

import android.app.PendingIntent
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.drawable.Icon
import android.net.Uri
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
import org.json.JSONArray
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
            Log.w(TAG, "No auth token — cannot trigger SOS")
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
        // 1. Get last known location
// ✅ NEW — reads as String, parses to Double
val latStr = prefs.getString(KEY_LAST_LAT, null)
val lngStr = prefs.getString(KEY_LAST_LNG, null)

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

        // 2. POST /api/emergency/start
        val emergencyId = startEmergencyApi(apiBase, token, lat, lng)
        if (emergencyId == null) {
            Log.e(TAG, "Failed to create emergency")
            return
        }

        // 3. POST /api/emergency/:id/web-stream
        val webUrl = generateWebStreamApi(apiBase, token, emergencyId)

        // 4. Send SMS via Android SmsManager
        sendSmsToContacts(prefs, token, apiBase, lat, lng, emergencyId, webUrl)

        // 5. Open app so user sees Emergency Mode
        openApp()
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
                val json = JSONObject(respText)
                val emergency = json.optJSONObject("emergency")
                emergency?.optString("id")?.takeIf { it.isNotEmpty() }
                    ?: emergency?.optString("_id")?.takeIf { it.isNotEmpty() }
            } else {
                null
            }
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
            } else {
                ""
            }

            Log.d(TAG, "webStream response [$code]: $respText")

            if (code in 200..299) {
                JSONObject(respText).optString("webUrl", "")
            } else {
                ""
            }
        } catch (e: Exception) {
            Log.e(TAG, "generateWebStreamApi failed", e)
            ""
        }
    }

    // ============ SMS ============

    private fun sendSmsToContacts(
        prefs: SharedPreferences,
        token: String,
        apiBase: String,
        lat: Double,
        lng: Double,
        emergencyId: String,
        webUrl: String,
    ) {
        try {
            // Fetch contacts from backend
            val url = URL("$apiBase/contacts")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                setRequestProperty("Authorization", "Bearer $token")
                connectTimeout = 15000
                readTimeout = 15000
            }

            val code = conn.responseCode
            if (code !in 200..299) {
                Log.e(TAG, "Failed to fetch contacts [$code]")
                return
            }

            val respText = conn.inputStream.bufferedReader().readText()
            val json = JSONObject(respText)
            val contacts: JSONArray = json.optJSONArray("contacts") ?: return

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
                val contact = contacts.getJSONObject(i)
                val phone = contact.optString("phone", "")
                if (phone.isNotEmpty()) {
                    try {
                        smsManager.sendTextMessage(
                            normalizePhone(phone),
                            null,
                            message,
                            null,
                            null,
                        )
                        Log.d(TAG, "SMS sent to $phone")
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to send SMS to $phone", e)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "sendSmsToContacts failed", e)
        }
    }

    private fun normalizePhone(phone: String): String {
        var cleaned = phone.replace(Regex("[^0-9]"), "")
        if (cleaned.startsWith("0")) cleaned = cleaned.substring(1)
        return if (!cleaned.startsWith("91")) "+91$cleaned" else "+$cleaned"
    }

/**
 * Flutter's shared_preferences may store doubles with a base64 prefix.
 * Extract the trailing numeric value safely.
 */
private fun extractDouble(raw: String?): Double? {
    if (raw.isNullOrEmpty()) return null
    raw.toDoubleOrNull()?.let { return it }
    val matches = Regex("""-?\d+\.?\d*""").findAll(raw).toList()
    return matches.lastOrNull()?.value?.toDoubleOrNull()
}

    // ============ OPEN APP ============

    private fun openApp() {
        try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            intent?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("from_tile", true)
            }
            if (intent != null) {
                startActivityAndCollapse(
                    PendingIntent.getActivity(
                        this,
                        0,
                        intent,
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                    ),
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open app", e)
        }
    }

    // ============ HELPER ============

    private suspend fun withContextMain(block: () -> Unit) {
        android.os.Handler(mainLooper).post(block)
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
    }
}