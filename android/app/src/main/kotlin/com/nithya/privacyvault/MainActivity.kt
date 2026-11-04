package com.nithya.privacyvault

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity (not FlutterActivity) because BiometricPrompt,
 * used by local_auth, needs a FragmentActivity host.
 */
class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // FLAG_SECURE: blocks screenshots, screen recording and the
        // recent-apps thumbnail for this window.
        MethodChannel(messenger, "vault/window").setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecure" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    if (enabled) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "vault/keystore").setMethodCallHandler(KeystoreChannel)
    }
}
