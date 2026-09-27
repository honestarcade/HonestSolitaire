package com.honestarcade.solitaire

import android.content.ActivityNotFoundException
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var sound: SoundBridge? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The volume keys set the media volume the game's sounds play at (#101).
        volumeControlStream = AudioManager.STREAM_MUSIC
    }

    // The app's whole Android surface: the private files directory (#83),
    // opening an https link in the browser (#91), and the sounds (#101). No
    // permission is needed for any of it, and
    // test/guards/platform_surface_test.dart keeps both channels to exactly
    // these methods.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "honestsolitaire/platform")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "filesDir" -> result.success(applicationContext.filesDir.absolutePath)
                    "openUrl" -> result.success(openUrl(call.argument<String>("url")))
                    else -> result.notImplemented()
                }
            }
        val bridge = SoundBridge(applicationContext)
        sound = bridge
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SoundBridge.CHANNEL)
            .setMethodCallHandler(bridge)
    }

    override fun onPause() {
        // The loop never plays behind another app; Dart restarts it on return.
        sound?.pauseMusic()
        super.onPause()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        sound?.release()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        sound?.release()
        sound = null
        super.onDestroy()
    }

    // Only https, through the system's own chooser; any failure is `false`,
    // which Dart shows as "no browser found". Never a crash.
    private fun openUrl(url: String?): Boolean {
        if (url == null || !url.startsWith("https://")) return false
        return try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                .addCategory(Intent.CATEGORY_BROWSABLE)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: Exception) {
            false
        }
    }
}
