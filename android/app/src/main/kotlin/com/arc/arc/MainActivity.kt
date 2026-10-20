package com.arc.arc

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val SECURE_CHANNEL = "com.arc.arc/secure_window"
    private val HAPTICS_CHANNEL = "com.arc.arc/haptics"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Setup Money Automation bridge for local Android SMS events
        MoneyAutomationBridge.setup(
            context = applicationContext,
            activity = this,
            methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MoneyAutomationBridge.METHOD_CHANNEL),
            eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, MoneyAutomationBridge.EVENT_CHANNEL)
        )
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecure" -> {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(true)
                }
                "disableSecure" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HAPTICS_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "vibrate") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val type = call.argument<String>("type")
            val pulse = when (type) {
                "selectionClick" -> HapticPulse(durationMs = 10L, amplitude = 70)
                "lightImpact" -> HapticPulse(durationMs = 18L, amplitude = 100)
                "mediumImpact" -> HapticPulse(durationMs = 28L, amplitude = 160)
                "heavyImpact" -> HapticPulse(durationMs = 42L, amplitude = 220)
                else -> null
            }

            if (pulse == null) {
                result.error("invalid_haptic_type", "Unknown haptic type: $type", null)
                return@setMethodCallHandler
            }

            result.success(vibrateIfEnabled(pulse))
        }
    }

    @Suppress("DEPRECATION")
    private fun vibrateIfEnabled(pulse: HapticPulse): Boolean {
        val hapticsEnabled = Settings.System.getInt(
            contentResolver,
            Settings.System.HAPTIC_FEEDBACK_ENABLED,
            1,
        ) != 0
        if (!hapticsEnabled) return false

        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

        if (!vibrator.hasVibrator()) return false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(
                VibrationEffect.createOneShot(pulse.durationMs, pulse.amplitude),
            )
        } else {
            vibrator.vibrate(pulse.durationMs)
        }
        return true
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        MoneyAutomationBridge.handleRequestPermissionsResult(this, requestCode, permissions, grantResults)
    }

    private data class HapticPulse(val durationMs: Long, val amplitude: Int)
}
