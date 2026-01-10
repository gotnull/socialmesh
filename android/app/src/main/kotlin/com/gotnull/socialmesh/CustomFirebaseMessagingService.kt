package com.gotnull.socialmesh

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import android.util.Log

/**
 * Custom Firebase Messaging Service to handle push notifications.
 * This service intercepts messages before they reach plugin services,
 * preventing crashes from plugins that expect specific message formats.
 */
class CustomFirebaseMessagingService : FirebaseMessagingService() {
    
    companion object {
        private const val TAG = "CustomFCMService"
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        Log.d(TAG, "Message received from: ${remoteMessage.from}")
        
        // Check if message contains data payload
        if (remoteMessage.data.isNotEmpty()) {
            Log.d(TAG, "Message data payload: ${remoteMessage.data}")
            
            // Handle the message data here if needed
            // For now, we just log it and let the Flutter app handle it via the plugin
        }

        // Check if message contains notification payload
        remoteMessage.notification?.let {
            Log.d(TAG, "Message Notification Body: ${it.body}")
            // The firebase_messaging plugin will automatically handle notification display
        }

        // Important: Call super to allow firebase_messaging plugin to process the message
        // But this prevents it from reaching live_activities plugin which crashes on Android
        try {
            super.onMessageReceived(remoteMessage)
        } catch (e: Exception) {
            Log.e(TAG, "Error in super.onMessageReceived", e)
            // Swallow the exception to prevent app crash
        }
    }

    override fun onNewToken(token: String) {
        Log.d(TAG, "Refreshed token: $token")
        super.onNewToken(token)
        
        // If you want to send tokens to your app server, do it here
    }
}
