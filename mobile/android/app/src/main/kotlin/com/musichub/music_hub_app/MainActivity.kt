package com.musichub.music_hub_app

import android.content.ContentUris
import android.content.Intent
import android.media.audiofx.Equalizer
import android.provider.MediaStore
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Must extend AudioServiceActivity so media notification / lock-screen
/// controls stay linked to the Flutter engine.
class MainActivity : AudioServiceActivity() {
    private val eqChannel = "music_hub/equalizer"
    private val widgetChannel = "music_hub/widget"
    private val localMediaChannel = "music_hub/local_media"
    private var equalizer: Equalizer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, localMediaChannel)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "scanAudio" -> result.success(scanLocalAudio())
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("LOCAL_MEDIA", e.message, null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, eqChannel)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "init" -> {
                            val sessionId = call.argument<Int>("sessionId") ?: 0
                            releaseEq()
                            if (sessionId != 0) {
                                equalizer = Equalizer(0, sessionId).apply { enabled = true }
                            }
                            result.success(equalizer != null)
                        }
                        "getBands" -> {
                            val eq = equalizer
                            if (eq == null) {
                                result.success(emptyList<Map<String, Any>>())
                                return@setMethodCallHandler
                            }
                            val bands = mutableListOf<Map<String, Any>>()
                            for (i in 0 until eq.numberOfBands) {
                                val center = eq.getCenterFreq(i.toShort()) / 1000
                                val level = eq.getBandLevel(i.toShort())
                                bands.add(
                                    mapOf(
                                        "index" to i,
                                        "centerHz" to center,
                                        "levelMb" to level.toInt(),
                                        "minMb" to eq.bandLevelRange[0].toInt(),
                                        "maxMb" to eq.bandLevelRange[1].toInt(),
                                    ),
                                )
                            }
                            result.success(bands)
                        }
                        "setBand" -> {
                            val eq = equalizer
                            if (eq == null) {
                                result.success(false)
                                return@setMethodCallHandler
                            }
                            val index = (call.argument<Int>("index") ?: 0).toShort()
                            val levelMb = (call.argument<Int>("levelMb") ?: 0).toShort()
                            eq.setBandLevel(index, levelMb)
                            result.success(true)
                        }
                        "setBands" -> {
                            val eq = equalizer
                            if (eq == null) {
                                result.success(false)
                                return@setMethodCallHandler
                            }
                            @Suppress("UNCHECKED_CAST")
                            val levels = call.argument<List<Int>>("levels") ?: emptyList()
                            val min = eq.bandLevelRange[0].toInt()
                            val max = eq.bandLevelRange[1].toInt()
                            for (i in 0 until eq.numberOfBands) {
                                val v = if (i < levels.size) levels[i] else 0
                                eq.setBandLevel(i.toShort(), v.coerceIn(min, max).toShort())
                            }
                            result.success(true)
                        }
                        "applyPreset" -> {
                            val eq = equalizer
                            if (eq == null) {
                                result.success(false)
                                return@setMethodCallHandler
                            }
                            val name = call.argument<String>("name") ?: "normal"
                            applyPreset(eq, name)
                            result.success(true)
                        }
                        "release" -> {
                            releaseEq()
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("EQ_ERROR", e.message, null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, widgetChannel)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "update" -> {
                            val title = call.argument<String>("title") ?: "Music Hub"
                            val artist = call.argument<String>("artist") ?: ""
                            val playing = call.argument<Boolean>("playing") ?: false
                            MusicHubWidgetProvider.pushUpdate(this, title, artist, playing)
                            result.success(true)
                        }
                        "clear" -> {
                            MusicHubWidgetProvider.pushUpdate(this, "Music Hub", "未播放", false)
                            result.success(true)
                        }
                        "consumePendingAction" -> {
                            val prefs = getSharedPreferences(MusicHubWidgetProvider.PREFS, MODE_PRIVATE)
                            val action = prefs.getString(MusicHubWidgetProvider.KEY_PENDING_ACTION, null)
                            if (action != null) {
                                prefs.edit().remove(MusicHubWidgetProvider.KEY_PENDING_ACTION).apply()
                            }
                            // also check launch intent
                            val fromIntent = intent?.getStringExtra(MusicHubWidgetProvider.EXTRA_WIDGET_ACTION)
                            if (fromIntent != null) {
                                intent?.removeExtra(MusicHubWidgetProvider.EXTRA_WIDGET_ACTION)
                                result.success(fromIntent)
                            } else {
                                result.success(action)
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("WIDGET_ERROR", e.message, null)
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val action = intent.getStringExtra(MusicHubWidgetProvider.EXTRA_WIDGET_ACTION)
        if (action != null) {
            getSharedPreferences(MusicHubWidgetProvider.PREFS, MODE_PRIVATE)
                .edit()
                .putString(MusicHubWidgetProvider.KEY_PENDING_ACTION, action)
                .apply()
        }
    }

    private fun applyPreset(eq: Equalizer, name: String) {
        val n = eq.numberOfBands.toInt()
        if (n <= 0) return
        val min = eq.bandLevelRange[0].toInt()
        val max = eq.bandLevelRange[1].toInt()
        fun clamp(v: Int) = v.coerceIn(min, max).toShort()

        val levels: IntArray = when (name) {
            "bass" -> intArrayOf(900, 600, 150, 0, -150)
            "vocal" -> intArrayOf(-250, 50, 700, 550, 150)
            "treble" -> intArrayOf(-250, -100, 50, 550, 900)
            "classical" -> intArrayOf(450, 200, 0, 250, 450)
            "pop" -> intArrayOf(350, 150, -100, 250, 450)
            "rock" -> intArrayOf(500, 200, -50, 300, 500)
            "jazz" -> intArrayOf(300, 100, 100, 200, 300)
            "electronic" -> intArrayOf(700, 200, -100, 200, 600)
            "cinematic" -> intArrayOf(550, 250, 0, 200, 400)
            "lofi" -> intArrayOf(400, 150, -200, -100, -300)
            "sad_ballad" -> intArrayOf(-100, 100, 400, 250, -50)
            "acoustic" -> intArrayOf(100, 200, 250, 150, 50)
            "hiphop" -> intArrayOf(800, 400, 0, 150, 250)
            "dance" -> intArrayOf(600, 200, -50, 350, 550)
            "podcast" -> intArrayOf(-300, 100, 600, 400, -100)
            // Karaoke / vocal-reduce: deeper mid scoop (~0.5–5 kHz lead vocal)
            // Stronger cut than before; still EQ-only, not AI stem separation.
            "karaoke" -> intArrayOf(450, -550, -1400, -1300, -250)
            else -> IntArray(5) { 0 }
        }
        for (i in 0 until n) {
            val idx = (i * levels.size) / n
            val level = levels[idx.coerceIn(0, levels.size - 1)]
            eq.setBandLevel(i.toShort(), clamp(level))
        }
    }

    private fun releaseEq() {
        try {
            equalizer?.enabled = false
            equalizer?.release()
        } catch (_: Exception) {
        }
        equalizer = null
    }

    /** MediaStore audio scan for local library (Flutter MethodChannel). */
    private fun scanLocalAudio(): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.MIME_TYPE,
            MediaStore.Audio.Media.IS_MUSIC,
            MediaStore.Audio.Media.IS_RINGTONE,
            MediaStore.Audio.Media.IS_NOTIFICATION,
            MediaStore.Audio.Media.IS_ALARM,
        )
        val sort = "${MediaStore.Audio.Media.ARTIST} COLLATE NOCASE ASC, ${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC"
        contentResolver.query(collection, projection, null, null, sort)?.use { c ->
            val idCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val dataCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
            val titleCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val albumCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val durCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val mimeCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.MIME_TYPE)
            val isMusicCol = c.getColumnIndex(MediaStore.Audio.Media.IS_MUSIC)
            val isRingCol = c.getColumnIndex(MediaStore.Audio.Media.IS_RINGTONE)
            val isNotifCol = c.getColumnIndex(MediaStore.Audio.Media.IS_NOTIFICATION)
            val isAlarmCol = c.getColumnIndex(MediaStore.Audio.Media.IS_ALARM)

            while (c.moveToNext()) {
                if (isRingCol >= 0 && c.getInt(isRingCol) != 0) continue
                if (isNotifCol >= 0 && c.getInt(isNotifCol) != 0) continue
                if (isAlarmCol >= 0 && c.getInt(isAlarmCol) != 0) continue
                if (isMusicCol >= 0 && c.getInt(isMusicCol) == 0) {
                    // Keep podcasts etc. that still have a path; skip only if flagged non-music with empty data later.
                }
                val id = c.getLong(idCol)
                val data = c.getString(dataCol) ?: ""
                val contentUri = ContentUris.withAppendedId(collection, id).toString()
                val path = if (data.isNotBlank()) data else contentUri
                val duration = c.getLong(durCol)
                if (duration in 1 until 5000) continue
                val mime = c.getString(mimeCol) ?: ""
                val format = when {
                    mime.contains("flac", true) -> "flac"
                    mime.contains("mpeg", true) || mime.contains("mp3", true) -> "mp3"
                    mime.contains("mp4", true) || mime.contains("m4a", true) || mime.contains("aac", true) -> "m4a"
                    mime.contains("ogg", true) || mime.contains("opus", true) -> "ogg"
                    mime.contains("wav", true) -> "wav"
                    else -> data.substringAfterLast('.', missingDelimiterValue = "audio").lowercase()
                }
                out.add(
                    mapOf(
                        "id" to id,
                        "path" to path,
                        "uri" to contentUri,
                        "title" to (c.getString(titleCol) ?: ""),
                        "artist" to (c.getString(artistCol) ?: ""),
                        "album" to (c.getString(albumCol) ?: ""),
                        "durationMs" to duration,
                        "format" to format,
                    ),
                )
            }
        }
        return out
    }

    override fun onDestroy() {
        releaseEq()
        super.onDestroy()
    }
}
