package com.arc.arc

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class SecretNotesMediaBridge(
    private val activity: Activity,
    private val channel: MethodChannel,
) {
    companion object {
        const val CHANNEL = "com.arc.arc/secret_notes_media"
        private const val RECORD_PERMISSION_REQUEST = 7312
    }

    private var recorder: MediaRecorder? = null
    private var player: MediaPlayer? = null
    private var recordingStartedAt = 0L
    private var pendingPath: String? = null
    private var pendingResult: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(::handleCall)
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startRecording" -> startRecording(call.argument("path"), result)
            "stopRecording" -> stopRecording(result)
            "playAudio" -> playAudio(call.argument("path"), result)
            "pauseAudio" -> {
                if (player?.isPlaying == true) player?.pause()
                result.success(null)
            }
            "stopAudio" -> {
                releasePlayer()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startRecording(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrBlank()) {
            result.error("invalid_path", "A recording path is required.", null)
            return
        }
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            pendingPath = path
            pendingResult = result
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                RECORD_PERMISSION_REQUEST,
            )
            return
        }
        beginRecording(path, result)
    }

    @Suppress("DEPRECATION")
    private fun beginRecording(path: String, result: MethodChannel.Result) {
        try {
            releaseRecorder()
            File(path).parentFile?.mkdirs()
            val nextRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(activity)
            } else {
                MediaRecorder()
            }
            nextRecorder.setAudioSource(MediaRecorder.AudioSource.MIC)
            nextRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            nextRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            nextRecorder.setAudioEncodingBitRate(128000)
            nextRecorder.setAudioSamplingRate(44100)
            nextRecorder.setOutputFile(path)
            nextRecorder.prepare()
            nextRecorder.start()
            recorder = nextRecorder
            recordingStartedAt = System.currentTimeMillis()
            result.success(true)
        } catch (error: Exception) {
            releaseRecorder()
            result.error("recording_failed", error.message, null)
        }
    }

    private fun stopRecording(result: MethodChannel.Result) {
        val duration = (System.currentTimeMillis() - recordingStartedAt).coerceAtLeast(0L)
        try {
            recorder?.stop()
            result.success(mapOf("durationMs" to duration))
        } catch (error: Exception) {
            result.error("recording_failed", error.message, null)
        } finally {
            releaseRecorder()
        }
    }

    private fun playAudio(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrBlank() || !File(path).exists()) {
            result.error("missing_audio", "The voice note file is unavailable.", null)
            return
        }
        try {
            releasePlayer()
            player = MediaPlayer().apply {
                setDataSource(path)
                setOnCompletionListener { releasePlayer() }
                prepare()
                start()
            }
            result.success(null)
        } catch (error: Exception) {
            releasePlayer()
            result.error("playback_failed", error.message, null)
        }
    }

    fun handlePermissionResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != RECORD_PERMISSION_REQUEST) return false
        val result = pendingResult
        val path = pendingPath
        pendingResult = null
        pendingPath = null
        if (result != null && path != null && grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            beginRecording(path, result)
        } else {
            result?.success(false)
        }
        return true
    }

    private fun releaseRecorder() {
        try { recorder?.release() } catch (_: Exception) {}
        recorder = null
        recordingStartedAt = 0L
    }

    private fun releasePlayer() {
        try { player?.stop() } catch (_: Exception) {}
        try { player?.release() } catch (_: Exception) {}
        player = null
    }
}
