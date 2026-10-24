package com.example.safeguard

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.Timer
import java.util.TimerTask

class AudioRecorder(
    private val context: Context,
    private val apiBase: String,
    private val token: String,
    private val emergencyId: String,
) {
    companion object {
        private const val TAG = "AudioRecorder"
        private const val CHUNK_SECONDS = 30
    }

    private var recorder: MediaRecorder? = null
    private var currentFile: File? = null
    private var chunkIndex = 0
    private var chunkStartMs = 0L
    private var timer: Timer? = null
    private var isRunning = false
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    fun start() {
        if (isRunning) return
        isRunning = true
        startChunk()
        timer = Timer().apply {
            scheduleAtFixedRate(object : TimerTask() {
                override fun run() { rotate() }
            }, CHUNK_SECONDS * 1000L, CHUNK_SECONDS * 1000L)
        }
    }

    fun stop() {
        isRunning = false
        timer?.cancel(); timer = null
        finalizeAndUpload()
    }

    private fun startChunk() {
        try {
            val dir = File(context.cacheDir, "emergency_audio").apply { mkdirs() }
            val file = File(dir, "chunk_${chunkIndex}_${System.currentTimeMillis()}.m4a")
            currentFile = file

            recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(context)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(44100)
                setAudioEncodingBitRate(64000)
                setOutputFile(file.absolutePath)
                prepare()
                start()
            }
            chunkStartMs = System.currentTimeMillis()
            Log.d(TAG, "Chunk $chunkIndex started")
        } catch (e: Exception) {
            Log.e(TAG, "startChunk failed", e)
        }
    }

    private fun rotate() {
        if (!isRunning) return
        finalizeAndUpload()
        chunkIndex++
        if (isRunning) startChunk()
    }

    private fun finalizeAndUpload() {
        val file = currentFile ?: return
        val index = chunkIndex
        val duration = ((System.currentTimeMillis() - chunkStartMs) / 1000).toInt()

        try {
            recorder?.stop()
            recorder?.release()
        } catch (e: Exception) {
            Log.e(TAG, "stop failed", e)
        }
        recorder = null
        currentFile = null

        scope.launch {
            if (file.exists() && file.length() > 5000) {
                uploadChunk(file, index, duration)
            }
            file.delete()
        }
    }

    private fun uploadChunk(file: File, index: Int, duration: Int) {
        val url = "$apiBase/emergency/$emergencyId/audio"
        val recordedAt = isoUtcNow()

        val ok = MultipartUploader.upload(
            url = url,
            token = token,
            file = file,
            fileField = "audio",
            fileName = "chunk_$index.m4a",
            mimeType = "audio/mp4",
            extraFields = mapOf(
                "chunkIndex" to index.toString(),
                "durationSeconds" to duration.toString(),
                "recordedAt" to recordedAt,
            ),
        )
        Log.d(TAG, "Chunk $index uploaded: $ok")
    }

    private fun isoUtcNow(): String {
        val fmt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        fmt.timeZone = TimeZone.getTimeZone("UTC")
        return fmt.format(Date())
    }
}