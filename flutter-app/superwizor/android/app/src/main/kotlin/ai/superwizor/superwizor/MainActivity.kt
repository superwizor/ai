package ai.superwizor.superwizor

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val fgsChannel = "superwizor/recording_fgs"

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
                else -> result.notImplemented()
            }
        }
    }
}
