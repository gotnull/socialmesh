package com.gotnull.socialmesh

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
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
 * 2. Shows notification when app is killed/background (FCM auto-display is overridden)
 * 3. Safely passes messages to parent (firebase_messaging plugin)
 * 4. Catches and logs any exceptions from downstream handlers
 */
class CustomFirebaseMessagingService : FirebaseMessagingService() {
    
    companion object {
        private const val TAG = "CustomFCMService"
        private const val CHANNEL_ID = "social_notifications"
        private const val CHANNEL_NAME = "Social Notifications"
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

        // Show notification manually since we're overriding the default FCM behavior
        // This ensures notifications are shown even when app is killed
        remoteMessage.notification?.let { notification ->
            showNotification(notification.title, notification.body, remoteMessage.data)
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

    private fun showNotification(title: String?, body: String?, data: Map<String, String>) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create notification channel for Android O+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for follows, likes, and comments"
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        // Create intent to open app when notification is tapped
        val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            // Pass notification data to the app
            data.forEach { (key, value) -> putExtra(key, value) }
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            System.currentTimeMillis().toInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title ?: "Socialmesh")
            .setContentText(body)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .build()

        notificationManager.notify(System.currentTimeMillis().toInt(), notification)
        Log.d(TAG, "Notification shown: $title - $body")
    }
}
