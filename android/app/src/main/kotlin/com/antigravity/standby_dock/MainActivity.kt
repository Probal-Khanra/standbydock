package com.antigravity.standby_dock

import android.content.ComponentName
import android.content.Context
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Handler
import android.os.Looper
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.Timer
import java.util.TimerTask

class MainActivity : FlutterActivity() {

    companion object {
        private const val MEDIA_EVENT_CHANNEL = "com.antigravity.standby_dock/media"
        private const val MEDIA_CONTROL_CHANNEL = "com.antigravity.standby_dock/media_control"
    }

    private var eventSink: EventChannel.EventSink? = null
    private var pollingTimer: Timer? = null
    private var activeController: MediaController? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // Native caching variables for resource optimization
    private var lastTitle: String? = null
    private var lastArtist: String? = null
    private var lastAlbum: String? = null
    private var lastIsPlaying: Boolean? = null
    private var lastHasSession: Boolean? = null
    private var lastArtworkBase64: String = ""
    private var lastBitmap: android.graphics.Bitmap? = null

    // Callback to detect real-time playback state changes
    private val mediaCallback = object : MediaController.Callback() {
        override fun onPlaybackStateChanged(state: PlaybackState?) {
            super.onPlaybackStateChanged(state)
            sendCurrentMediaState()
        }

        override fun onMetadataChanged(metadata: MediaMetadata?) {
            super.onMetadataChanged(metadata)
            sendCurrentMediaState()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // --- EventChannel: streams media metadata to Dart ---
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    startPolling()
                }

                override fun onCancel(arguments: Any?) {
                    stopPolling()
                    eventSink = null
                }
            })

        // --- MethodChannel: receives transport commands from Dart ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CONTROL_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "openNotificationSettings") {
                    try {
                        val intent = android.content.Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
                        intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = android.content.Intent(android.provider.Settings.ACTION_SETTINGS)
                            intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(false)
                        } catch (e2: Exception) {
                            result.error("FAILED_TO_OPEN", e2.message, null)
                        }
                    }
                    return@setMethodCallHandler
                }

                val controller = activeController
                if (controller == null) {
                    result.error("NO_SESSION", "No active media session", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "play" -> {
                        controller.transportControls.play()
                        result.success(null)
                    }
                    "pause" -> {
                        controller.transportControls.pause()
                        result.success(null)
                    }
                    "next" -> {
                        controller.transportControls.skipToNext()
                        result.success(null)
                    }
                    "previous" -> {
                        controller.transportControls.skipToPrevious()
                        result.success(null)
                    }
                    "playPause" -> {
                        val state = controller.playbackState?.state
                        if (state == PlaybackState.STATE_PLAYING) {
                            controller.transportControls.pause()
                        } else {
                            controller.transportControls.play()
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startPolling() {
        pollingTimer?.cancel()
        pollingTimer = Timer().apply {
            scheduleAtFixedRate(object : TimerTask() {
                override fun run() {
                    mainHandler.post { sendCurrentMediaState() }
                }
            }, 0, 1000) // Poll every 1 second
        }
    }

    private fun stopPolling() {
        activeController?.unregisterCallback(mediaCallback)
        activeController = null
        pollingTimer?.cancel()
        pollingTimer = null
        // Reset cache to force next update on reconnection
        lastTitle = null
        lastArtist = null
        lastAlbum = null
        lastIsPlaying = null
        lastHasSession = null
        lastArtworkBase64 = ""
        lastBitmap = null
    }

    private fun sendCurrentMediaState() {
        val sink = eventSink ?: return

        try {
            val mediaSessionManager =
                getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager

            val listenerComponent = ComponentName(this, MediaNotificationListener::class.java)
            val controllers: List<MediaController>

            try {
                controllers = mediaSessionManager.getActiveSessions(listenerComponent)
            } catch (e: SecurityException) {
                // Notification listener permission not granted yet
                sink.success(
                    mapOf(
                        "error" to "PERMISSION_REQUIRED",
                        "message" to "Notification Listener permission not granted"
                    )
                )
                return
            }

            if (controllers.isEmpty()) {
                if (lastHasSession == false) {
                    return // Cache hit: already sent empty state
                }
                lastTitle = ""
                lastArtist = ""
                lastAlbum = ""
                lastIsPlaying = false
                lastHasSession = false
                lastArtworkBase64 = ""
                sink.success(
                    mapOf(
                        "title" to "",
                        "artist" to "",
                        "album" to "",
                        "artwork" to "",
                        "isPlaying" to false,
                        "hasSession" to false
                    )
                )
                return
            }

            // Prioritize the best active media controller:
            // 1. Currently playing (STATE_PLAYING) with a non-empty title.
            // 2. Any controller with a non-empty title.
            // 3. Fall back to the first available controller in the list.
            var bestController = controllers.firstOrNull { c ->
                val state = c.playbackState?.state
                val title = c.metadata?.getString(MediaMetadata.METADATA_KEY_TITLE)
                state == PlaybackState.STATE_PLAYING && !title.isNullOrEmpty()
            }

            if (bestController == null) {
                bestController = controllers.firstOrNull { c ->
                    val title = c.metadata?.getString(MediaMetadata.METADATA_KEY_TITLE)
                    !title.isNullOrEmpty()
                }
            }

            val controller = bestController ?: controllers[0]

            if (activeController != controller) {
                activeController?.unregisterCallback(mediaCallback)
                activeController = controller
                controller.registerCallback(mediaCallback)
            }

            val metadata = controller.metadata
            val playbackState = controller.playbackState

            val title = metadata?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: ""
            val artist = metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST) ?: ""
            val album = metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM) ?: ""
            val isPlaying = playbackState?.state == PlaybackState.STATE_PLAYING
            val hasSession = true

            val bitmap = metadata?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
                ?: metadata?.getBitmap(MediaMetadata.METADATA_KEY_ART)
                ?: metadata?.getBitmap(MediaMetadata.METADATA_KEY_DISPLAY_ICON)

            // Determine if the artwork has loaded since the last check
            val artworkJustLoaded = (lastArtworkBase64.isEmpty() && bitmap != null)

            // Skip event pushing if state is identical to avoid redundant channel and serialization overhead
            if (title == lastTitle && artist == lastArtist && album == lastAlbum &&
                isPlaying == lastIsPlaying && hasSession == lastHasSession &&
                !artworkJustLoaded) {
                return
            }

            // Encode album art as base64 - Optimized: only scale/compress if bitmap reference changed
            var artworkBase64 = lastArtworkBase64
            if (bitmap != lastBitmap) {
                artworkBase64 = ""
                if (bitmap != null) {
                    try {
                        val stream = java.io.ByteArrayOutputStream()
                        val scaled = android.graphics.Bitmap.createScaledBitmap(bitmap, 300, 300, true)
                        scaled.compress(android.graphics.Bitmap.CompressFormat.PNG, 85, stream)
                        artworkBase64 = Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
                        stream.close()
                        if (scaled != bitmap) scaled.recycle()
                    } catch (e: Exception) {
                        // Artwork extraction can fail silently
                    }
                }
            }

            // Cache new state
            lastTitle = title
            lastArtist = artist
            lastAlbum = album
            lastIsPlaying = isPlaying
            lastHasSession = hasSession
            lastArtworkBase64 = artworkBase64
            lastBitmap = bitmap

            sink.success(
                mapOf(
                    "title" to title,
                    "artist" to artist,
                    "album" to album,
                    "artwork" to artworkBase64,
                    "isPlaying" to isPlaying,
                    "hasSession" to true
                )
            )
        } catch (e: Exception) {
            sink.error("MEDIA_ERROR", e.message, null)
        }
    }

    override fun onDestroy() {
        stopPolling()
        super.onDestroy()
    }
}
