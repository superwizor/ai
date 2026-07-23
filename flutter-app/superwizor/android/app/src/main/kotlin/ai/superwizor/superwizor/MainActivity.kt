package ai.superwizor.superwizor

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.media.MediaPlayer
import android.media.AudioAttributes
import android.os.Vibrator
import android.content.Context
import android.os.VibrationEffect
import java.util.Timer
import java.util.TimerTask

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth's
// biometric prompt (app-lock). Engine wiring below is unchanged.
class MainActivity : FlutterFragmentActivity() {
    private val audioSessionChannel = "superwizor/audio_session"
    private val fgsChannel = "superwizor/recording_fgs"
    private val liveActivityChannel = "ai.superwizor/live_activity"
    private val reminderChannel = "ai.superwizor/reminder_service"
    
    private var reminderTimer: Timer? = null
    private var reminderMediaPlayer: MediaPlayer? = null
    
    private var reminderIntervalMinutes: Int = 0
    private var reminderIntervalSeconds: Int = 0
    private var soundEnabled: Boolean = false
    private var hapticsEnabled: Boolean = false
    private var startTimeMillis: Long = 0
    private var accumulatedMillis: Long = 0
    private var expectedRemindersFired: Int = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Call-interruption probe (2026-07-23). Android never pauses our
        // recorder on an incoming call — the mic is silently muted and the
        // file keeps growing with dead audio. Dart polls getAudioMode()
        // while recording and pauses itself on RINGTONE/IN_CALL/
        // IN_COMMUNICATION. Same channel name as iOS AudioSessionHelper
        // (which handles "reactivate"); here only the Android-side method.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            audioSessionChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAudioMode" -> {
                    val am = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
                    result.success(am.mode)
                }
                else -> result.notImplemented()
            }
        }

        // Recording foreground-service control (docs/28 WS5). Started when
        // a recording begins so the OS won't kill the app while it's
        // backgrounded during a phone call.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            fgsChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val intent = Intent(this, RecordingForegroundService::class.java).apply {
                        action = RecordingForegroundService.ACTION_START
                        putExtra(RecordingForegroundService.EXTRA_TITLE, call.argument<String>("title"))
                        putExtra(RecordingForegroundService.EXTRA_BODY, call.argument<String>("body"))
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stop" -> {
                    val intent = Intent(this, RecordingForegroundService::class.java).apply {
                        action = RecordingForegroundService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(true)
                }
                "update" -> {
                    val intent = Intent(this, RecordingForegroundService::class.java).apply {
                        action = RecordingForegroundService.ACTION_UPDATE
                        putExtra(RecordingForegroundService.EXTRA_TITLE, call.argument<String>("title"))
                        putExtra(RecordingForegroundService.EXTRA_BODY, call.argument<String>("body"))
                    }
                    startService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Live Activity / AppWidget control — mirrors recording state
        // to the home-screen widget so therapists can see session
        // status without opening the app.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            liveActivityChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    ActiveSessionWidgetProvider.patientAlias =
                        call.argument<String>("patientAlias") ?: ""
                    ActiveSessionWidgetProvider.elapsedSeconds =
                        call.argument<Int>("elapsedSeconds") ?: 0
                    ActiveSessionWidgetProvider.statusText = "Sesja w toku"
                    ActiveSessionWidgetProvider.isPaused = false
                    ActiveSessionWidgetProvider.isActive = true
                    ActiveSessionWidgetProvider.reportSessionId = null
                    ActiveSessionWidgetProvider.pushUpdate(this)
                    result.success(true)
                }
                "update" -> {
                    val status = call.argument<String>("status") ?: "recording"
                    ActiveSessionWidgetProvider.elapsedSeconds =
                        call.argument<Int>("elapsedSeconds") ?: 0
                    ActiveSessionWidgetProvider.isPaused = status == "paused" || status == "interrupted"
                    ActiveSessionWidgetProvider.statusText = when (status) {
                        "recording" -> "Sesja w toku"
                        "paused" -> "Pauza"
                        "interrupted" -> "Wstrzymane (połączenie)"
                        "uploading" -> "AI opracowuje wnioski z sesji..."
                        "analyzing" -> "AI opracowuje wnioski z sesji..."
                        "reportReady" -> "Nowy raport czeka w kartotece"
                        else -> status
                    }
                    ActiveSessionWidgetProvider.pushUpdate(this)
                    result.success(true)
                }
                "reportReady" -> {
                    val sessionId = call.argument<String>("sessionId")
                    ActiveSessionWidgetProvider.reportSessionId = sessionId
                    ActiveSessionWidgetProvider.statusText = "Nowy raport czeka w kartotece"
                    ActiveSessionWidgetProvider.pushUpdate(this)
                    result.success(true)
                }
                "stop" -> {
                    ActiveSessionWidgetProvider.isActive = false
                    ActiveSessionWidgetProvider.reportSessionId = null
                    ActiveSessionWidgetProvider.pushUpdate(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        
        // Reminder Service for playing native alarms in the background
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            reminderChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    reminderIntervalMinutes = call.argument<Int>("intervalMinutes") ?: 0
                    reminderIntervalSeconds = call.argument<Int>("intervalSeconds") ?: 0
                    soundEnabled = call.argument<Boolean>("soundEnabled") ?: false
                    hapticsEnabled = call.argument<Boolean>("hapticsEnabled") ?: false
                    accumulatedMillis = (call.argument<Int>("elapsedMillis") ?: 0).toLong()
                    
                    val intervalMillis = if (reminderIntervalSeconds > 0) reminderIntervalSeconds * 1000L else reminderIntervalMinutes * 60000L
                    expectedRemindersFired = if (intervalMillis > 0) (accumulatedMillis / intervalMillis).toInt() else 0
                    
                    startReminderTimer()
                    result.success(true)
                }
                "pause" -> {
                    accumulatedMillis = (call.argument<Int>("elapsedMillis") ?: 0).toLong()
                    stopReminderTimer()
                    result.success(true)
                }
                "resume" -> {
                    reminderIntervalMinutes = call.argument<Int>("intervalMinutes") ?: 0
                    reminderIntervalSeconds = call.argument<Int>("intervalSeconds") ?: 0
                    soundEnabled = call.argument<Boolean>("soundEnabled") ?: false
                    hapticsEnabled = call.argument<Boolean>("hapticsEnabled") ?: false
                    accumulatedMillis = (call.argument<Int>("elapsedMillis") ?: 0).toLong()
                    
                    val intervalMillis = if (reminderIntervalSeconds > 0) reminderIntervalSeconds * 1000L else reminderIntervalMinutes * 60000L
                    expectedRemindersFired = if (intervalMillis > 0) (accumulatedMillis / intervalMillis).toInt() else 0
                    
                    startReminderTimer()
                    result.success(true)
                }
                "update" -> {
                    reminderIntervalMinutes = call.argument<Int>("intervalMinutes") ?: 0
                    reminderIntervalSeconds = call.argument<Int>("intervalSeconds") ?: 0
                    soundEnabled = call.argument<Boolean>("soundEnabled") ?: false
                    hapticsEnabled = call.argument<Boolean>("hapticsEnabled") ?: false
                    result.success(true)
                }
                "stop" -> {
                    stopReminderTimer()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun startReminderTimer() {
        stopReminderTimer()
        if (reminderMediaPlayer == null) {
            var resId = resources.getIdentifier("sfx_session_end_2", "raw", packageName)
            if (resId == 0) {
                resId = resources.getIdentifier("sfx_session_end", "raw", packageName)
            }
            if (resId != 0) {
                reminderMediaPlayer = MediaPlayer.create(this, resId).apply {
                    setAudioAttributes(AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build())
                }
            }
        }
        
        startTimeMillis = System.currentTimeMillis()
        reminderTimer = Timer()
        reminderTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                checkReminder()
            }
        }, 500, 500)
    }
    
    private fun stopReminderTimer() {
        reminderTimer?.cancel()
        reminderTimer = null
        startTimeMillis = 0
    }
    
    private fun checkReminder() {
        val intervalMillis = if (reminderIntervalSeconds > 0) reminderIntervalSeconds * 1000L else reminderIntervalMinutes * 60000L
        if (intervalMillis <= 0L || startTimeMillis == 0L) return
        val elapsedNowMillis = accumulatedMillis + (System.currentTimeMillis() - startTimeMillis)
        val expected = (elapsedNowMillis / intervalMillis).toInt()
        
        if (expected > expectedRemindersFired) {
            expectedRemindersFired = expected
            playReminder()
        }
    }
    
    private fun playReminder() {
        if (soundEnabled) {
            reminderMediaPlayer?.apply {
                seekTo(0)
                start()
            }
        }
        if (hapticsEnabled) {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(500, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(500)
            }
        }
    }
}
