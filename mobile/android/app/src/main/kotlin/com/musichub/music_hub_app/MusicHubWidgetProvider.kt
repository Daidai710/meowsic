package com.musichub.music_hub_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class MusicHubWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context))
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_PREV, ACTION_PLAY, ACTION_NEXT -> {
                // Forward to Flutter via a sticky broadcast the app listens to,
                // and also open / focus the app so audio_service can handle if needed.
                val launch = Intent(context, MainActivity::class.java).apply {
                    action = intent.action
                    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
                    putExtra(EXTRA_WIDGET_ACTION, intent.action)
                }
                context.startActivity(launch)
                // Persist last command for Flutter cold start
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .edit()
                    .putString(KEY_PENDING_ACTION, intent.action)
                    .apply()
            }
            ACTION_REFRESH -> {
                val mgr = AppWidgetManager.getInstance(context)
                val ids = mgr.getAppWidgetIds(ComponentName(context, MusicHubWidgetProvider::class.java))
                onUpdate(context, mgr, ids)
            }
        }
    }

    companion object {
        const val PREFS = "music_hub_widget"
        const val KEY_TITLE = "title"
        const val KEY_ARTIST = "artist"
        const val KEY_PLAYING = "playing"
        const val KEY_PENDING_ACTION = "pending_action"
        const val EXTRA_WIDGET_ACTION = "widget_action"

        const val ACTION_PREV = "com.musichub.music_hub_app.WIDGET_PREV"
        const val ACTION_PLAY = "com.musichub.music_hub_app.WIDGET_PLAY"
        const val ACTION_NEXT = "com.musichub.music_hub_app.WIDGET_NEXT"
        const val ACTION_REFRESH = "com.musichub.music_hub_app.WIDGET_REFRESH"

        fun buildViews(context: Context): RemoteViews {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val title = prefs.getString(KEY_TITLE, "Music Hub") ?: "Music Hub"
            val artist = prefs.getString(KEY_ARTIST, "未播放") ?: "未播放"
            val playing = prefs.getBoolean(KEY_PLAYING, false)

            val views = RemoteViews(context.packageName, R.layout.music_hub_widget)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_artist, artist)
            views.setImageViewResource(
                R.id.widget_play,
                if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
            )

            val openApp = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, openApp)
            views.setOnClickPendingIntent(R.id.widget_title, openApp)
            views.setOnClickPendingIntent(R.id.widget_artist, openApp)

            views.setOnClickPendingIntent(R.id.widget_prev, actionPi(context, ACTION_PREV, 1))
            views.setOnClickPendingIntent(R.id.widget_play, actionPi(context, ACTION_PLAY, 2))
            views.setOnClickPendingIntent(R.id.widget_next, actionPi(context, ACTION_NEXT, 3))
            return views
        }

        private fun actionPi(context: Context, action: String, req: Int): PendingIntent {
            val intent = Intent(context, MusicHubWidgetProvider::class.java).setAction(action)
            return PendingIntent.getBroadcast(
                context,
                req,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        fun pushUpdate(context: Context, title: String, artist: String, playing: Boolean) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(KEY_TITLE, title)
                .putString(KEY_ARTIST, artist)
                .putBoolean(KEY_PLAYING, playing)
                .apply()
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, MusicHubWidgetProvider::class.java))
            for (id in ids) {
                mgr.updateAppWidget(id, buildViews(context))
            }
        }
    }
}
