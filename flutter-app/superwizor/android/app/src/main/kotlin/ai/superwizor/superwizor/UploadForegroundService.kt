package ai.superwizor.superwizor

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import io.flutter.plugin.common.EventChannel

/**
 * `dataSync` foreground service that buys the Dart upload runner a window
 * of foreground process priority while the app is backgrounded (docs/58).
 *
 * NOTHING is transferred here — the upload queue stays in Dart. On Android
 * the isolate does keep running after the app goes to background; it only
 * loses process priority, because the recording FGS and the wakelock are
 * both released before the upload is even enqueued. A multi-megabyte PUT
 * then competes with everything else on the device and can stall for hours
 * (production incident: 19 h 52 min). iOS needed the opposite fix — there
 * the bytes go to `nsurlsessiond` — see the asymmetry note at the top of
 * lib/uploads/background_upload_channel.dart.
 *
 * Lifecycle is driven from Dart via the `ai.superwizor/upload_fgs`
 * MethodChannel (registered in MainActivity): `start` while the app is
 * still foreground and the queue has pending rows, `stop` once it drains.
 * The only thing the service reports back — on the
 * `ai.superwizor/upload_fgs_events` EventChannel — is the OS cutting the
 * window short, see [onTimeout].
 *
 * Modelled on RecordingForegroundService; what differs is the FGS type,
 * a separate notification channel/id (both notifications can be up at the
 * same time) and the Android 15 timeout callback.
 */
class UploadForegroundService : Service() {

    companion object {
        const val ACTION_START = "ai.superwizor.superwizor.action.START_UPLOAD_WINDOW"
        const val EXTRA_PENDING_COUNT = "pendingCount"

        /** The single event Dart listens for; see [onTimeout]. */
        const val EVENT_TIMEOUT = "timeout"

        private const val TAG = "UploadFgs"
        private const val CHANNEL_ID = "upload_queue"

        // 4711 belongs to RecordingForegroundService — a session that ends
        // while the previous upload is still running would show both.
        private const val NOTIFICATION_ID = 4712

        // Held statically because the service is a separate component from
        // the activity that owns the channel: the sink is installed by
        // MainActivity's StreamHandler and cleared on cancel / activity
        // destroy, so a stale engine is never written to.
        @Volatile
        private var eventSink: EventChannel.EventSink? = null

        fun setEventSink(sink: EventChannel.EventSink?) {
            eventSink = sink
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == ACTION_START) {
            // Re-delivered start with a fresh count just refreshes the
            // notification text; there is no separate "update" method.
            startInForeground(intent?.getIntExtra(EXTRA_PENDING_COUNT, 1) ?: 1)
        } else {
            // Dart stops us with stopService(), so any other intent means
            // something we don't understand woke the service up. Stand down
            // rather than leave a "wysyłanie" notification with no runner
            // behind it. Destroying the service inside onStartCommand also
            // clears the startForegroundService() obligation, so this cannot
            // trip the 5 s "did not then call startForeground" crash.
            Log.w(TAG, "onStartCommand without ACTION_START — standing down")
            stopForegroundCompat()
            stopSelf()
        }
        // Never resurrect ourselves: a restarted service with no Dart runner
        // behind it (the isolate dies with the process) would show a phantom
        // upload notification forever. Pending rows are picked up by the
        // queue on the next launch anyway.
        return START_NOT_STICKY
    }

    /**
     * Android 15 (targetSdk 35 is pinned in build.gradle.kts, so this is
     * live the day it ships) caps cumulative `dataSync` runtime at 6 h per
     * 24 h. When the budget runs out the system calls this instead of
     * killing us outright, and we MUST stop promptly or it throws
     * ForegroundServiceDidNotStopInTimeException.
     *
     * Dart is told so it can fall back to foreground-only uploading — the
     * next `start` in the same 24 h window would be refused anyway.
     *
     * The one-argument `onTimeout(startId)` overload is `shortService`-only
     * and never fires for `dataSync`, hence only this one is overridden.
     */
    override fun onTimeout(startId: Int, fgsType: Int) {
        Log.w(TAG, "dataSync budget exhausted (startId=$startId, type=$fgsType) — stopping")
        // Service lifecycle callbacks run on the main thread, which is the
        // platform thread the EventChannel requires. Emit before tearing
        // down so the event is queued while the engine is certainly alive.
        eventSink?.success(mapOf("event" to EVENT_TIMEOUT))
        stopForegroundCompat()
        stopSelf()
    }

    private fun startInForeground(pendingCount: Int) {
        createChannel()

        val notification = buildNotification(pendingCount)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            // A start that reached us from the background is already refused
            // at the startForegroundService() call site, so MainActivity has
            // returned false to Dart long before we get here. What does reach
            // this catch is API 35 declining because the 6 h/24 h dataSync
            // budget is already spent — the same situation as [onTimeout],
            // only reported before the window ever opened. Say so on the
            // event channel, otherwise Dart is left believing it has a window
            // (`start` already answered true) and never falls back.
            //
            // Losing the window is survivable; taking the app down with an
            // uncaught exception is not.
            Log.w(TAG, "startForeground refused: ${e.javaClass.simpleName}", e)
            eventSink?.success(mapOf("event" to EVENT_TIMEOUT))
            stopSelf()
        }
    }

    /**
     * Notification copy lives in the native string resources on purpose:
     * Dart passes only a count, so there is no i18n round-trip to make at
     * upload time. Polish is primary, same as RecordingForegroundService.
     */
    private fun buildNotification(pendingCount: Int): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        // Not getQuantityString: after "wysyłanie" Polish takes the genitive
        // plural, which is the same word for 2, 3, 5 and 22 ("nagrań"), so
        // the only distinction that exists is one-vs-many.
        val title = if (pendingCount > 1) {
            getString(R.string.upload_fgs_title_many, pendingCount)
        } else {
            getString(R.string.upload_fgs_title_one)
        }

        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(getString(R.string.upload_fgs_body))
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setOngoing(true)
            .setContentIntent(contentIntent)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (mgr.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    getString(R.string.upload_fgs_channel_name),
                    NotificationManager.IMPORTANCE_LOW, // silent, no heads-up
                ).apply {
                    description = getString(R.string.upload_fgs_channel_description)
                    setShowBadge(false)
                }
                mgr.createNotificationChannel(channel)
            }
        }
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    override fun onDestroy() {
        stopForegroundCompat()
        super.onDestroy()
    }
}
