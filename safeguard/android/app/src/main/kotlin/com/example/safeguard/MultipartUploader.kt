package com.example.safeguard

import android.util.Log
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

object MultipartUploader {
    private const val TAG = "MultipartUploader"

    fun upload(
        url: String,
        token: String,
        file: File,
        fileField: String,
        fileName: String,
        mimeType: String,
        extraFields: Map<String, String>,
    ): Boolean {
        val boundary = "----SafeGuardBoundary${System.currentTimeMillis()}"
        var conn: HttpURLConnection? = null
        return try {
            conn = (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                doOutput = true
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
                connectTimeout = 30000
                readTimeout = 60000
            }

            conn.outputStream.use { os ->
                for ((k, v) in extraFields) {
                    os.write("--$boundary\r\n".toByteArray())
                    os.write("Content-Disposition: form-data; name=\"$k\"\r\n\r\n".toByteArray())
                    os.write("$v\r\n".toByteArray())
                }
                os.write("--$boundary\r\n".toByteArray())
                os.write("Content-Disposition: form-data; name=\"$fileField\"; filename=\"$fileName\"\r\n".toByteArray())
                os.write("Content-Type: $mimeType\r\n\r\n".toByteArray())
                file.inputStream().use { it.copyTo(os) }
                os.write("\r\n".toByteArray())
                os.write("--$boundary--\r\n".toByteArray())
            }

            val code = conn.responseCode
            Log.d(TAG, "Upload $url → $code")
            code in 200..299
        } catch (e: Exception) {
            Log.e(TAG, "Upload failed", e)
            false
        } finally {
            conn?.disconnect()
        }
    }
}