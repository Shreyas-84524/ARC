package com.arc.arc

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * MoneyAutomationBridge provides the local platform bridge between Android OS
 * telephonic SMS events and the Flutter Riverpod processing layer.
 *
 * PRIVACY GUARANTEES:
 * - Operates purely locally on the device.
 * - No data is written to disk or sent over network.
 * - If [isEnabled] is false, all incoming events are immediately dropped.
 */
object MoneyAutomationBridge {
    const val METHOD_CHANNEL = "com.arc.arc/money_automation"
    const val EVENT_CHANNEL = "com.arc.arc/money_automation_events"
    const val SMS_PERMISSION_REQUEST_CODE = 4201
    private const val PREFS_NAME = "arc_money_automation_prefs"
    private const val PREF_KEY_ENABLED = "is_enabled"
    private const val MAX_BUFFERED_EVENTS = 5

    @Volatile
    var isEnabled: Boolean = false

    private var eventSink: EventChannel.EventSink? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val pendingEventsBuffer = mutableListOf<HashMap<String, Any>>()

    fun isAutomationEnabled(context: Context): Boolean {
        if (isEnabled) return true
        return try {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getBoolean(PREF_KEY_ENABLED, false)
        } catch (e: Exception) {
            false
        }
    }

    fun clearBufferedEvents() {
        synchronized(pendingEventsBuffer) {
            pendingEventsBuffer.clear()
        }
    }

    fun setup(
        context: Context,
        activity: Activity,
        methodChannel: MethodChannel,
        eventChannel: EventChannel
    ) {
        // Restore persistent enabled state on engine startup
        isEnabled = isAutomationEnabled(context)

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> {
                    result.success(true)
                }
                "checkPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        context,
                        Manifest.permission.RECEIVE_SMS
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestPermission" -> {
                    val alreadyGranted = ContextCompat.checkSelfPermission(
                        context,
                        Manifest.permission.RECEIVE_SMS
                    ) == PackageManager.PERMISSION_GRANTED
                    if (alreadyGranted) {
                        result.success("granted")
                        return@setMethodCallHandler
                    }

                    pendingPermissionResult = result
                    ActivityCompat.requestPermissions(
                        activity,
                        arrayOf(Manifest.permission.RECEIVE_SMS),
                        SMS_PERMISSION_REQUEST_CODE
                    )
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", context.packageName, null)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("settings_error", e.localizedMessage, null)
                    }
                }
                "setListenerEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    isEnabled = enabled
                    try {
                        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                            .edit()
                            .putBoolean(PREF_KEY_ENABLED, enabled)
                            .apply()
                    } catch (e: Exception) {
                        // Ignore SharedPreferences failures
                    }
                    if (!enabled) {
                        clearBufferedEvents()
                    }
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                // Immediately flush any transient buffered events to Flutter
                synchronized(pendingEventsBuffer) {
                    if (events != null && pendingEventsBuffer.isNotEmpty()) {
                        for (event in pendingEventsBuffer) {
                            try {
                                events.success(event)
                            } catch (e: Exception) {
                                // Channel error
                            }
                        }
                        pendingEventsBuffer.clear()
                    }
                }
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    fun handleRequestPermissionsResult(
        activity: Activity,
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode != SMS_PERMISSION_REQUEST_CODE) return false

        val result = pendingPermissionResult ?: return false
        pendingPermissionResult = null

        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            result.success("granted")
        } else {
            val showRationale = ActivityCompat.shouldShowRequestPermissionRationale(
                activity,
                Manifest.permission.RECEIVE_SMS
            )
            if (showRationale) {
                result.success("denied")
            } else {
                result.success("permanentlyDenied")
            }
        }
        return true
    }

    /**
     * Called when an SMS is received by [MoneySmsReceiver].
     * Dispatches event to the Flutter stream if enabled, or holds in a transient
     * buffer until the Flutter engine stream attaches.
     */
    fun onSmsReceived(context: Context, sender: String, body: String, timestamp: Long) {
        if (!isAutomationEnabled(context)) {
            return
        }

        val eventMap = HashMap<String, Any>()
        eventMap["sender"] = sender
        eventMap["body"] = body
        eventMap["timestamp"] = timestamp
        eventMap["sourceType"] = "sms"

        mainHandler.post {
            val sink = eventSink
            if (sink != null) {
                try {
                    sink.success(eventMap)
                } catch (e: Exception) {
                    // Ignore transient channel errors
                }
            } else {
                // Buffer transient event until Flutter engine attaches onListen
                synchronized(pendingEventsBuffer) {
                    if (pendingEventsBuffer.size >= MAX_BUFFERED_EVENTS) {
                        pendingEventsBuffer.removeAt(0)
                    }
                    pendingEventsBuffer.add(eventMap)
                }
            }
        }
    }
}
