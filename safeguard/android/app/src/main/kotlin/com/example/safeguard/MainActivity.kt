package com.example.safeguard

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.safeguard/native"
    private var fromTile = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        fromTile = intent?.getBooleanExtra("from_tile", false) ?: false
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        
        // Handle re-launch (app was running in background, tile tapped)
        fromTile = intent.getBooleanExtra("from_tile", false)
        flutterEngine?.dartExecutor?.binaryMessenger?.let {
            MethodChannel(it, CHANNEL).invokeMethod("openEmergencyMode", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "wasLaunchedFromTile" -> result.success(fromTile)
                "clearTileLaunch" -> {
                    fromTile = false
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}