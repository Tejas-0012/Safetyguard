package com.example.safeguard

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.example.safeguard/native"
        private var instance: MainActivity? = null
        private var methodChannel: MethodChannel? = null

        fun notifyEmergencyStopped() {
            Handler(Looper.getMainLooper()).post {
                methodChannel?.invokeMethod("onEmergencyStopped", null)
            }
        }
    }

    private var fromTile = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        fromTile = intent?.getBooleanExtra("from_tile", false) ?: false
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance == this) {
            instance = null
            methodChannel = null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        fromTile = intent.getBooleanExtra("from_tile", false)
        val openEmergency = intent.getBooleanExtra("openEmergencyMode", false)

        if (fromTile || openEmergency) {
            flutterEngine?.dartExecutor?.binaryMessenger?.let {
                MethodChannel(it, CHANNEL).invokeMethod("openEmergencyMode", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            when (call.method) {
                "wasLaunchedFromTile" -> result.success(fromTile)
                "clearTileLaunch" -> {
                    fromTile = false
                    result.success(true)
                }

                // Shake detection
                "startShakeDetection" -> {
                    SafeGuardForegroundService.enableShake(this, true)
                    result.success(true)
                }
                "stopShakeDetection" -> {
                    SafeGuardForegroundService.enableShake(this, false)
                    result.success(true)
                }
                "isShakeDetectionRunning" -> {
                    result.success(prefs.getBoolean("flutter.safeguard_shake_enabled", false))
                }

                // Voice activation
                "startVoiceActivation" -> {
                    SafeGuardForegroundService.enableVoice(this, true)
                    result.success(true)
                }
                "stopVoiceActivation" -> {
                    SafeGuardForegroundService.enableVoice(this, false)
                    result.success(true)
                }
                "isVoiceActivationRunning" -> {
                    result.success(prefs.getBoolean("flutter.safeguard_voice_enabled", false))
                }

                // Emergency Foreground
                "startEmergencyForeground" -> {
                    SafeGuardForegroundService.startEmergency(this)
                    result.success(true)
                }
                "stopEmergencyForeground" -> {
                    SafeGuardForegroundService.stopEmergency(this)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }
}
