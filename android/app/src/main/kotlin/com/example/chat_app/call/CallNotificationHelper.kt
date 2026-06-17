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

    fun buildOngoingCallNotification(
        title: String,
        body: String,
        isVideo: Boolean,
        isMicEnabled: Boolean,
        isCameraEnabled: Boolean,
    ): Notification {
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

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CALL_CHANNEL_ID)
        } else {
            Notification.Builder(context)
        }

        builder
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

        builder.addAction(
            buildAction(
                action = MainActivity.ACTION_TOGGLE_MIC,
                requestCode = TOGGLE_MIC_REQUEST_CODE,
                iconRes = if (isMicEnabled) R.drawable.ic_pip_mic_24 else R.drawable.ic_pip_mic_off_24,
                title = if (isMicEnabled) "Mute" else "Unmute",
            ),
        )

        if (isVideo) {
            builder.addAction(
                buildAction(
                    action = MainActivity.ACTION_TOGGLE_CAMERA,
                    requestCode = TOGGLE_CAMERA_REQUEST_CODE,
                    iconRes = if (isCameraEnabled) {
                        R.drawable.ic_pip_videocam_24
                    } else {
                        R.drawable.ic_pip_videocam_off_24
                    },
                    title = if (isCameraEnabled) "Camera off" else "Camera on",
                ),
            )
        }

        builder.addAction(
            buildAction(
                action = MainActivity.ACTION_HANGUP_CALL,
                requestCode = HANGUP_REQUEST_CODE,
                iconRes = R.drawable.ic_pip_call_end_24,
                title = "Hang up",
            ),
        )

        return builder.build()
    }

    private fun buildAction(
        action: String,
        requestCode: Int,
        iconRes: Int,
        title: String,
    ): Notification.Action {
        val intent = Intent(context, CallActionReceiver::class.java).apply {
            this.action = action
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or pendingIntentImmutableFlag(),
        )
        return Notification.Action.Builder(iconRes, title, pendingIntent).build()
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
        private const val TOGGLE_MIC_REQUEST_CODE = 4103
        private const val TOGGLE_CAMERA_REQUEST_CODE = 4104
    }
}
