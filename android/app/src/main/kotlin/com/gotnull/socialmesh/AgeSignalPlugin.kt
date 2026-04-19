package com.gotnull.socialmesh

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Scaffold for Google Play Age Signals integration.
 *
 * Currently returns [AgeGroup.unknown] for all requests. To activate:
 *
 * 1. Add the Play Age Signals (or Children's Safety) SDK dependency to
 *    android/app/build.gradle.kts, e.g.:
 *      implementation("com.google.android.libraries.childrenssafety:age-verification:<version>")
 *
 * 2. Replace the stub body of [fetchAgeSignal] with a real SDK call that
 *    maps the platform-returned age range to one of the following strings
 *    (matching the Dart [AgeGroup] enum values):
 *      "unknown" | "under13" | "teen" | "adult"
 *
 * 3. Update the "source" field to "playAgeSignals" when a real signal is
 *    received.
 *
 * 4. Register in MainActivity.kt:
 *      flutterEngine.plugins.add(AgeSignalPlugin())
 */
class AgeSignalPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
            binding.binaryMessenger,
            "com.socialmesh/age_signal",
        )
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "fetchAgeSignal" -> result.success(fetchAgeSignal())
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun fetchAgeSignal(): Map<String, String> {
        // Scaffold: no SDK wired yet.  Returns unknown so the app falls back
        // to self-attestation via the in-app eligibility gate.
        return mapOf(
            "ageGroup" to "unknown",
            "source" to "unknown",
        )
    }
}
