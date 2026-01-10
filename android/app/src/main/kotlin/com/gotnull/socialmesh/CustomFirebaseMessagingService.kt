package com.gotnull.socialmesh

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import android.util.Log

/**
 * Custom Firebase Messaging Service to handle push notifications.
 * 
 * This service intercepts FCM messages before they reach plugin services,
 * specifically to prevent crashes from the live_activities plugin which
 * is iOS-only but still receives Android FCM broadcasts.
 * 
 * The service:
 * 1. Logs message details for debugging
 * 2. Safely passes messages to parent (firebase_messaging plugin)
 * 3. Catches and logs any exceptions from downstream handlers
 */
class CustomFirebaseMessagingService : FirebaseMessagingService() {
    
    companion object {
        private const val TAG = "CustomFCMService"
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        Log.d(TAG, "Message received from: ${remoteMessage.from}")
        
        // Log data payload
        if (remoteMessage.data.isNotEmpty()) {
            Log.d(TAG, "Message data payload: ${remoteMessage.data}")
        }

        // Log notification payload
        remoteMessage.notification?.let {
            Log.d(TAG, "Message Notification Body: ${it.body}")
        }

        // Pass to firebase_messaging plugin, catching any downstream errors
        // This prevents crashes from live_activities plugin (iOS-only) which
        // registers for FCM broadcasts but crashes with NullPointerException on Android
        try {
            super.onMessageReceived(remoteMessage)
        } catch (e: NullPointerException) {
            // Expected from live_activities plugin on Android - safe to ignore
            Log.w(TAG, "NullPointerException in downstream handler (likely live_activities): ${e.message}")
        } catch (e: Exception) {
            // Unexpected error - log full stack trace for debugging
            Log.e(TAG, "Unexpected error in downstream message handler", e)
        }
    }

    override fun onNewToken(token: String) {
        Log.d(TAG, "FCM token refreshed")
        super.onNewToken(token)
    }
}
