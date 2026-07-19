package ai.superwizor.superwizor

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth's
// biometric prompt (app-lock). Engine wiring below is unchanged.
class MainActivity : FlutterFragmentActivity() {
    private val fgsChannel = "superwizor/recording_fgs"
    private val liveActivityChannel = "ai.superwizor/live_activity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
    }
}
