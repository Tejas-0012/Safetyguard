package com.example.safeguard

import android.telephony.SmsManager
import android.util.Log
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

class EmergencyApiClient(private val apiBase: String, private val token: String) {

    fun startEmergency(lat: Double, lng: Double, source: String): Pair<String, List<ReceiverLink>>? {
        return try {
            val url = URL("$apiBase/emergency/start")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Authorization", "Bearer $token")
                doOutput = true
            }
            val body = JSONObject().apply {
                put("latitude", lat)
                put("longitude", lng)
                put("triggerSource", source)
            }
            OutputStreamWriter(conn.outputStream).use { it.write(body.toString()) }

            if (conn.responseCode in 200..299) {
                val respText = conn.inputStream.bufferedReader().readText()
                val json = JSONObject(respText)
                val emergency = json.optJSONObject("emergency")
                val id = emergency?.optString("id") ?: emergency?.optString("_id") ?: return null
                
                val links = mutableListOf<ReceiverLink>()
                val linksArray = json.optJSONArray("receiverLinks")
                if (linksArray != null) {
                    for (i in 0 until linksArray.length()) {
                        val obj = linksArray.getJSONObject(i)
                        links.add(ReceiverLink(
                            obj.optString("contactName", ""),
                            obj.optString("contactPhone", ""),
                            obj.optString("webUrl", ""),
                            obj.optString("token", "")
                        ))
                    }
                }
                Pair(id, links)
            } else null
        } catch (e: Exception) {
            Log.e("ApiClient", "startEmergency failed", e)
            null
        }
    }

    fun sendSms(links: List<ReceiverLink>, userName: String): Int {
        val smsManager = SmsManager.getDefault()
        var sent = 0
        for (link in links) {
            try {
                smsManager.sendTextMessage(link.contactPhone, null, 
                    "Hi ${link.contactName}, $userName has activated an SOS alert! Track live: ${link.webUrl}", null, null)
                sent++
            } catch (_: Exception) {}
        }
        return sent
    }
}