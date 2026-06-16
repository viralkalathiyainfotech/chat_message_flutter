package com.example.chat_app.call

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.example.chat_app.MainActivity
import com.example.chat_app.R

class CallNotificationHelper(private val context: Context) {
    fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            CALL_CHANNEL_ID,
            "Active calls",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Controls for ongoing calls"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setSound(null, null)
        }

        notificationManager.createNotificationChannel(channel)
    }

    fun buildOngoingCallNotification(title: String, body: String): Notification {
        val openIntent = Intent(context, MainActivity::class.java).apply {
            action = MainActivity.ACTION_OPEN_CALL
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPendingIntent = PendingIntent.getActivity(
            context,
            OPEN_CALL_REQUEST_CODE,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or pendingIntentImmutableFlag(),
        )

        val hangupIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = MainActivity.ACTION_HANGUP_CALL
        }
        val hangupPendingIntent = PendingIntent.getBroadcast(
            context,
            HANGUP_REQUEST_CODE,
            hangupIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or pendingIntentImmutableFlag(),
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CALL_CHANNEL_ID)
        } else {
            Notification.Builder(context)
        }

        return builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(openPendingIntent)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_CALL)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(true)
            .setWhen(System.currentTimeMillis())
            .setUsesChronometer(true)
            .setShowWhen(true)
            .addAction(
                Notification.Action.Builder(
                    R.mipmap.ic_launcher,
                    "Hang up",
                    hangupPendingIntent,
                ).build(),
            )
            .build()
    }

    private val notificationManager: NotificationManager
        get() = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun pendingIntentImmutableFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
    }

    companion object {
        const val CALL_CHANNEL_ID = "ongoing_calls"
        const val CALL_NOTIFICATION_ID = 2101
        private const val OPEN_CALL_REQUEST_CODE = 4101
        private const val HANGUP_REQUEST_CODE = 4102
    }
}
