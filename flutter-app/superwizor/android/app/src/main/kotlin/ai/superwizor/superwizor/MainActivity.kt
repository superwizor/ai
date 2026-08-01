package ai.superwizor.superwizor

import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
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
    private val uploadFgsChannel = "ai.superwizor/upload_fgs"
    private val uploadFgsEventsChannel = "ai.superwizor/upload_fgs_events"
    
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

        // Upload-window control (docs/58). Not an uploader: the queue stays
        // in Dart and this only asks for a dataSync foreground service so the
        // isolate keeps foreground process priority once the recording FGS
        // and the wakelock are gone. See UploadForegroundService.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            uploadFgsChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val pendingCount = call.argument<Int>("pendingCount") ?: 1
                    result.success(startUploadWindow(pendingCount))
                }
                "stop" -> {
                    stopUploadWindow()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // The only thing the service reports back: the OS cutting the
        // dataSync window short (Android 15, 6 h per 24 h).
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            uploadFgsEventsChannel,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                UploadForegroundService.setEventSink(events)
            }

            override fun onCancel(arguments: Any?) {
                UploadForegroundService.setEventSink(null)
            }
        })

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
    
    /**
     * Asks for the upload window. Returns false — never an exception across
     * the channel — when the OS refuses, so Dart can just keep uploading in
     * the foreground.
     */
    private fun startUploadWindow(pendingCount: Int): Boolean {
        val intent = Intent(this, UploadForegroundService::class.java).apply {
            action = UploadForegroundService.ACTION_START
            putExtra(UploadForegroundService.EXTRA_PENDING_COUNT, pendingCount)
        }
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            true
        } catch (e: Exception) {
            // API 31+ throws ForegroundServiceStartNotAllowedException when
            // the call reaches us with the app already in the background
            // (API 34+ forbids background-started dataSync outright), and
            // API 35 refuses once the 6 h/24 h budget is spent. Caught as
            // Exception on purpose: naming that class in the catch clause
            // would reference a type that does not exist below API 31, and
            // no start failure is worth a PlatformException here.
            Log.w(TAG, "upload window refused: ${e.javaClass.simpleName}", e)
            false
        }
    }

    /**
     * stopService (not an ACTION_STOP intent like the recording service uses)
     * because the queue usually drains while the app is in the background,
     * and a background startService() would itself be illegal on API 26+.
     * onDestroy in the service removes the notification.
     */
    private fun stopUploadWindow() {
        try {
            stopService(Intent(this, UploadForegroundService::class.java))
        } catch (e: Exception) {
            Log.w(TAG, "stopping upload window failed: ${e.javaClass.simpleName}", e)
        }
    }

    override fun onDestroy() {
        // The isolate that owns the upload queue dies with this engine, so
        // nothing should be written into a stale sink afterwards.
        UploadForegroundService.setEventSink(null)
        // …and the window itself is worthless without that isolate: left
        // running it would show "Wysyłanie…" with nothing behind it. Only
        // a swipe-away is covered by android:stopWithTask; a back-press
        // finish lands here instead. Backgrounding — the case this whole
        // feature exists for — is onStop, not onDestroy, so the window
        // survives it. A configuration-change recreation keeps the service
        // and the new engine picks the queue straight back up.
        if (!isChangingConfigurations) {
            stopUploadWindow()
        }
        super.onDestroy()
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

    private companion object {
        // Same tag as UploadForegroundService so one logcat filter covers
        // the whole upload window: adb logcat -s UploadFgs
        const val TAG = "UploadFgs"
    }
}
