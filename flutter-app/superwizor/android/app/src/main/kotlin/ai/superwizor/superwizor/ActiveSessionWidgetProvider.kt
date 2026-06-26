package ai.superwizor.superwizor

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.app.PendingIntent
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews

/**
 * AppWidget that mirrors the active recording session status on the
 * Android home screen. Updated via MethodChannel from Flutter; uses
 * the system [android.widget.Chronometer] widget for real-time timer
 * ticking without waking the Flutter engine in the background.
 *
 * State is stored in companion-object fields (in-process only) —
 * if the process is killed, the widget resets to idle on next update.
 * This is intentional: the recording itself lives in a foreground
 * service, and when the app resumes it re-pushes the current state.
 */
class ActiveSessionWidgetProvider : AppWidgetProvider() {

    companion object {
        // In-memory state pushed from Flutter via MethodChannel.
        var patientAlias: String = ""
        var statusText: String = ""
        var elapsedSeconds: Int = 0
        var isPaused: Boolean = false
        var isActive: Boolean = false
        var reportSessionId: String? = null

        /**
         * Push the current state to all widget instances. Called from
         * [MainActivity] when the Flutter MethodChannel fires.
         */
        fun pushUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, ActiveSessionWidgetProvider::class.java)
            )
            if (ids.isEmpty()) return

            val views = buildRemoteViews(context)
            for (id in ids) {
                manager.updateAppWidget(id, views)
            }
        }

        private fun buildRemoteViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.active_session_widget)

            // Make the entire widget clickable to launch the app
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingIntent = launchIntent?.let {
                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
                PendingIntent.getActivity(context, 0, it, flags)
            }
            if (pendingIntent != null) {
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }

            if (!isActive) {
                // Render a clean idle/ready state instead of an empty box
                views.setViewVisibility(R.id.recording_dot, View.GONE)
                views.setTextViewText(R.id.patient_alias, "Superwizor AI")
                views.setTextViewText(R.id.status_text, "Brak aktywnej sesji")
                views.setViewVisibility(R.id.timer, View.GONE)
                return views
            }

            views.setViewVisibility(R.id.recording_dot, View.VISIBLE)
            views.setTextViewText(R.id.patient_alias, patientAlias)
            views.setTextViewText(R.id.status_text, statusText)

            if (reportSessionId != null) {
                // Report ready — hide the timer, show status only.
                views.setViewVisibility(R.id.timer, View.GONE)
            } else {
                views.setViewVisibility(R.id.timer, View.VISIBLE)
                // Set the Chronometer base so it shows the correct elapsed
                // time. Chronometer counts from `base` to now, so:
                //   base = SystemClock.elapsedRealtime() - elapsed * 1000
                val base = SystemClock.elapsedRealtime() - elapsedSeconds * 1000L
                views.setChronometer(R.id.timer, base, null, !isPaused)
            }

            return views
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val views = buildRemoteViews(context)
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
