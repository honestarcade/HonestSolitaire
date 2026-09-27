package com.honestarcade.solitaire

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // The app's whole Android surface: the private files directory (#83) and
    // opening an https link in the browser (#91). No permission is needed for
    // either, and test/guards/platform_surface_test.dart keeps this list to
    // exactly these two methods.
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
