package com.gotnull.socialmesh

import android.app.Activity
import android.app.Application
import android.content.Intent
import android.os.Bundle
import android.os.Process
import android.util.Log
import kotlin.system.exitProcess

/**
 * Custom Application class to handle uncaught exceptions,
 * particularly the Google Play Billing Library 8.0.0 crash
 * where ProxyBillingActivity receives a null PendingIntent.
 */
class SocialmeshApplication : Application() {

    companion object {
        private const val TAG = "SocialmeshApp"

        // Depth cap on cause-chain walks, so a self-referential cause cannot
        // spin the handler of a process that is already failing.
        private const val MAX_CAUSE_DEPTH = 12

        private const val FLUTTER_LIBRARY = "libflutter.so"
        private const val NATIVE_LIBRARY_SUFFIX = ".so"
    }

    private var startedActivities = 0

    override fun onCreate() {
        super.onCreate()

        trackForegroundActivities()

        // Set up a default uncaught exception handler to catch billing crashes
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()

        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            // Check if this is the known billing library crash
            if (isBillingLibraryCrash(throwable)) {
                Log.e(TAG, "Caught billing library crash (null PendingIntent), suppressing", throwable)
                // Don't propagate this crash - it's a known Google Play Billing issue
                // The purchase flow will fail gracefully on the Flutter side
                return@setDefaultUncaughtExceptionHandler
            }

            // An install whose native libraries are absent cannot start the
            // Flutter engine, and will fail this way on every launch. Explain
            // that to the user instead of dying with a system crash dialog.
            if (isMissingNativeLibraryCrash(throwable) && showBrokenInstallScreen()) {
                Log.e(TAG, "Native libraries are missing from this install", throwable)
                Process.killProcess(Process.myPid())
                exitProcess(10)
            }

            // For all other crashes, use the default handler (Crashlytics, etc.)
            defaultHandler?.uncaughtException(thread, throwable)
        }
    }

    /**
     * Hands the user the recovery screen, in a separate process so it outlives
     * the process that failed to start. Returns false when the screen was not
     * shown, so the caller falls back to the default handler: nothing is
     * suppressed silently.
     */
    private fun showBrokenInstallScreen(): Boolean {
        // A background wake (push message, scheduled work) must not throw a
        // full-screen error in front of whatever the user is actually doing.
        if (startedActivities <= 0) return false

        return try {
            startActivity(
                Intent(this, BrokenInstallActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            true
        } catch (failure: Exception) {
            Log.e(TAG, "Could not show the broken-install screen", failure)
            false
        }
    }

    /**
     * Check whether the crash is a package missing the native libraries the
     * Flutter engine loads at startup, which happens when an install carries no
     * ABI split: sideloaded from a bare base APK, cloned into a container app,
     * or left half-written by an interrupted update.
     */
    private fun isMissingNativeLibraryCrash(throwable: Throwable): Boolean =
        causeChain(throwable).any { cause ->
            val message = cause.message ?: return@any false
            // The library file has to be named, so that an UnsatisfiedLinkError
            // for a missing JNI method - a code defect, not a broken package -
            // still reports as the crash it is.
            message.contains(NATIVE_LIBRARY_SUFFIX) &&
                (cause is UnsatisfiedLinkError || message.contains(FLUTTER_LIBRARY))
        }

    private fun causeChain(throwable: Throwable): Sequence<Throwable> =
        generateSequence(throwable) { current -> current.cause.takeIf { it !== current } }
            .take(MAX_CAUSE_DEPTH)

    private fun trackForegroundActivities() {
        registerActivityLifecycleCallbacks(object : ActivityLifecycleCallbacks {
            override fun onActivityStarted(activity: Activity) {
                startedActivities++
            }

            override fun onActivityStopped(activity: Activity) {
                startedActivities--
            }

            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit

            override fun onActivityResumed(activity: Activity) = Unit

            override fun onActivityPaused(activity: Activity) = Unit

            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit

            override fun onActivityDestroyed(activity: Activity) = Unit
        })
    }
    
    /**
     * Check if the throwable is the known Google Play Billing Library crash
     * where ProxyBillingActivity.onCreate receives a null PendingIntent.
     */
    private fun isBillingLibraryCrash(throwable: Throwable): Boolean {
        // Check for the specific NullPointerException in ProxyBillingActivity
        val cause = throwable.cause ?: throwable
        
        if (cause is NullPointerException) {
            val stackTrace = cause.stackTrace
            for (element in stackTrace) {
                if (element.className.contains("ProxyBillingActivity") &&
                    element.methodName == "onCreate") {
                    return true
                }
            }
            
            // Also check the message for the specific error
            val message = cause.message ?: ""
            if (message.contains("getIntentSender") && message.contains("PendingIntent")) {
                return true
            }
        }
        
        // Check if it's wrapped in a RuntimeException
        if (throwable is RuntimeException && 
            throwable.message?.contains("ProxyBillingActivity") == true) {
            return isBillingLibraryCrash(throwable.cause ?: return false)
        }
        
        return false
    }
}
