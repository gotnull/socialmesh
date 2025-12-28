package com.gotnull.socialmesh

import android.app.Application
import android.util.Log

/**
 * Custom Application class to handle uncaught exceptions,
 * particularly the Google Play Billing Library 8.0.0 crash
 * where ProxyBillingActivity receives a null PendingIntent.
 */
class SocialmeshApplication : Application() {
    
    companion object {
        private const val TAG = "SocialmeshApp"
    }
    
    override fun onCreate() {
        super.onCreate()
        
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
            
            // For all other crashes, use the default handler (Crashlytics, etc.)
            defaultHandler?.uncaughtException(thread, throwable)
        }
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
