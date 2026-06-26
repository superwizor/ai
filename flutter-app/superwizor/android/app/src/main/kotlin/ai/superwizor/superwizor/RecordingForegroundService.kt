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

/**
 * Microphone foreground service that keeps the recording process alive
 * while the app is backgrounded — e.g. when the therapist answers a
 * phone call mid-session (docs/28 WS5).
 *
 * The `record` plugin does NOT manage a foreground service, so without
 * this an extended backgrounding (a long call, memory pressure) lets
 * Android kill the process and lose the in-progress recording. With a
 * `foregroundServiceType=microphone` service running, the OS keeps the
 * app alive and microphone access stays granted in the background.
 *
 * Lifecycle is driven from Dart via the `superwizor/recording_fgs`
 * MethodChannel (see RecordingForegroundService.kt registration in
 * MainActivity and lib/services/recording_foreground_service.dart):
 * start when recording begins, stop on stop/cancel/error. The partial
 * recording is still protected by the manifest + orphan-recovery scan
 * (WS1) regardless, so this is defense-in-depth, not the only net.
 */
class RecordingForegroundService : Service() {

    companion object {
        const val ACTION_START = "ai.superwizor.superwizor.action.START_RECORDING"
        const val ACTION_STOP = "ai.superwizor.superwizor.action.STOP_RECORDING"
        const val ACTION_UPDATE = "ai.superwizor.superwizor.action.UPDATE_STATUS"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"

        private const val CHANNEL_ID = "recording_session"
        private const val NOTIFICATION_ID = 4711

        // Polish-primary fallbacks; Dart passes localized strings via the
        // start intent so the notification respects the user's locale.
        private const val DEFAULT_TITLE = "Trwa nagrywanie sesji"
        private const val DEFAULT_BODY =
            "Superwizor nagrywa sesję. Nie zamykaj aplikacji."
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForegroundCompat()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_UPDATE -> {
                val title = intent.getStringExtra(EXTRA_TITLE) ?: DEFAULT_TITLE
                val body = intent.getStringExtra(EXTRA_BODY) ?: DEFAULT_BODY
                updateNotification(title, body)
            }
            else -> {
                val title = intent?.getStringExtra(EXTRA_TITLE) ?: DEFAULT_TITLE
                val body = intent?.getStringExtra(EXTRA_BODY) ?: DEFAULT_BODY
                startInForeground(title, body)
            }
        }
        // Do NOT auto-restart with a null intent if the OS kills us: a
        // resurrected service with no recorder behind it would show a
        // phantom "recording" notification. Recovery is handled by the
        // WS1 orphan scan on next launch instead.
        return START_NOT_STICKY
    }

    private fun startInForeground(title: String, body: String) {
        createChannel()

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        val notification: Notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setOngoing(true)
            .setContentIntent(contentIntent)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    /** Update the existing foreground notification text without restarting the service. */
    private fun updateNotification(title: String, body: String) {
        createChannel()

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        val notification: Notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setOngoing(true)
            .setContentIntent(contentIntent)
            .build()

        val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        mgr.notify(NOTIFICATION_ID, notification)
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (mgr.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Nagrywanie sesji",
                    NotificationManager.IMPORTANCE_LOW, // silent, no heads-up
                ).apply {
                    description = "Powiadomienie aktywne podczas nagrywania sesji."
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
