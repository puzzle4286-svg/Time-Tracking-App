package io.github.puzzle4286svg.lifestring

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    /** True while another app's screen (e.g. the file picker) is open for us. */
    private var awaitingResult = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AppIcon.register(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    @Deprecated("Still used by plugins such as file_picker")
    @Suppress("DEPRECATION")
    override fun startActivityForResult(intent: Intent, requestCode: Int, options: Bundle?) {
        awaitingResult = true
        super.startActivityForResult(intent, requestCode, options)
    }

    @Deprecated("Still used by plugins such as file_picker")
    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        awaitingResult = false
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onStop() {
        super.onStop()
        // Switching the launcher entry closes this screen, so a new icon is
        // only applied once the user has left the app (D50) — not while a
        // picker we opened is in front, which would lose its result.
        if (!awaitingResult && !isChangingConfigurations) AppIcon.applyPending(this)
    }
}
