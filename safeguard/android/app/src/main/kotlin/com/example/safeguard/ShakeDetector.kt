package com.example.safeguard

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.util.Log
import kotlin.math.sqrt

class ShakeDetector(
    private val onShakeTriggered: () -> Unit
) : SensorEventListener {

    companion object {
        private const val TAG = "ShakeDetector"
        private const val SHAKE_THRESHOLD_G = 2.5f
        private const val SHAKE_COUNT_REQUIRED = 3
        private const val SHAKE_WINDOW_MS = 2000L
        private const val MIN_INTERVAL_MS = 200L
        private const val COOLDOWN_MS = 30000L
    }

    private var isListening = false
    private var shakeCount = 0
    private var firstShakeTime = 0L
    private var lastShakeTime = 0L
    private var lastTriggerTime = 0L

    fun start(sensorManager: SensorManager): Boolean {
        if (isListening) return true
        val accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        if (accelerometer == null) {
            Log.e(TAG, "No accelerometer available on device")
            return false
        }
        val registered = sensorManager.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_GAME)
        isListening = registered
        Log.d(TAG, "Shake detection registered: $registered")
        return registered
    }

    fun stop(sensorManager: SensorManager) {
        if (!isListening) return
        sensorManager.unregisterListener(this)
        isListening = false
        shakeCount = 0
        Log.d(TAG, "Shake detection stopped")
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || event.sensor.type != Sensor.TYPE_ACCELEROMETER) return
        if (!isListening) return

        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]
        val gForce = sqrt(x * x + y * y + z * z) / SensorManager.GRAVITY_EARTH

        val now = System.currentTimeMillis()
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
                    Log.d(TAG, "🚨 Shake pattern detected! Triggering SOS...")
                    shakeCount = 0
                    lastTriggerTime = now
                    onShakeTriggered()
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}

