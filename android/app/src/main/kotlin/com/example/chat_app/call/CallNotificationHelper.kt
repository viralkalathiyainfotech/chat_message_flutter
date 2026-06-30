package com.example.chat_app.call

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Person
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import com.example.chat_app.MainActivity
import com.example.chat_app.R

class CallNotificationHelper(private val context: Context) {
    fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val ongoingChannel = NotificationChannel(
            CALL_CHANNEL_ID,
            "Active calls",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Controls for ongoing calls"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setSound(null, null)
        }

        val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val incomingChannel = NotificationChannel(
            INCOMING_CALL_CHANNEL_ID,
            "Incoming calls",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Full-screen incoming call alerts"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setSound(ringtoneUri, audioAttributes)
            enableVibration(true)
            vibrationPattern = INCOMING_CALL_VIBRATION_PATTERN
        }

        notificationManager.createNotificationChannel(ongoingChannel)
        notificationManager.createNotificationChannel(incomingChannel)
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

    fun buildScreenShareNotification(
        title: String,
        body: String,
    ): Notification {
        val openPendingIntent = buildActivityPendingIntent(
            MainActivity.ACTION_OPEN_CALL,
            SCREEN_SHARE_REQUEST_CODE,
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
            .setCategory(Notification.CATEGORY_SERVICE)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(true)
            .setWhen(System.currentTimeMillis())
            .setShowWhen(true)
            .build()
    }

    fun showIncomingCallNotification(
        title: String,
        body: String,
        callerName: String,
        isVideo: Boolean,
    ) {
        notificationManager.notify(
            INCOMING_CALL_NOTIFICATION_ID,
            buildIncomingCallNotification(
                title = title,
                body = body,
                callerName = callerName,
                isVideo = isVideo,
            ),
        )
    }

    fun cancelIncomingCallNotification() {
        notificationManager.cancel(INCOMING_CALL_NOTIFICATION_ID)
    }

    private fun buildIncomingCallNotification(
        title: String,
        body: String,
        callerName: String,
        isVideo: Boolean,
    ): Notification {
        val fullScreenPendingIntent = buildActivityPendingIntent(
            action = MainActivity.ACTION_OPEN_INCOMING_CALL,
            requestCode = OPEN_INCOMING_CALL_REQUEST_CODE,
        )
        val declinePendingIntent = buildActivityPendingIntent(
            action = MainActivity.ACTION_DECLINE_CALL,
            requestCode = DECLINE_INCOMING_CALL_REQUEST_CODE,
        )
        val answerPendingIntent = buildActivityPendingIntent(
            action = MainActivity.ACTION_ANSWER_CALL,
            requestCode = ANSWER_INCOMING_CALL_REQUEST_CODE,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, INCOMING_CALL_CHANNEL_ID)
        } else {
            Notification.Builder(context)
        }

        builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body.ifEmpty { callerName })
            .setContentIntent(fullScreenPendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setOngoing(true)
            .setAutoCancel(false)
            .setCategory(Notification.CATEGORY_CALL)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setPriority(Notification.PRIORITY_MAX)
            .setDefaults(Notification.DEFAULT_SOUND or Notification.DEFAULT_VIBRATE)
            .setVibrate(INCOMING_CALL_VIBRATION_PATTERN)
            .setWhen(System.currentTimeMillis())
            .setShowWhen(true)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val caller = Person.Builder()
                .setName(callerName)
                .setImportant(true)
                .build()
            builder.setStyle(
                Notification.CallStyle.forIncomingCall(
                    caller,
                    declinePendingIntent,
                    answerPendingIntent,
                ),
            )
        } else {
            builder.addAction(
                Notification.Action.Builder(
                    R.drawable.ic_pip_call_end_24,
                    "Decline",
                    declinePendingIntent,
                ).build(),
            )
            builder.addAction(
                Notification.Action.Builder(
                    if (isVideo) R.drawable.ic_pip_videocam_24 else R.drawable.ic_call_24,
                    "Answer",
                    answerPendingIntent,
                ).build(),
            )
        }

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

    private fun buildActivityPendingIntent(action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            this.action = action
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or pendingIntentImmutableFlag(),
        )
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
        const val INCOMING_CALL_CHANNEL_ID = "incoming_calls_full_screen"
        const val CALL_NOTIFICATION_ID = 2101
        const val INCOMING_CALL_NOTIFICATION_ID = 2102
        private val INCOMING_CALL_VIBRATION_PATTERN = longArrayOf(0, 900, 350, 900)
        private const val OPEN_CALL_REQUEST_CODE = 4101
        private const val HANGUP_REQUEST_CODE = 4102
        private const val TOGGLE_MIC_REQUEST_CODE = 4103
        private const val TOGGLE_CAMERA_REQUEST_CODE = 4104
        private const val OPEN_INCOMING_CALL_REQUEST_CODE = 4105
        private const val ANSWER_INCOMING_CALL_REQUEST_CODE = 4106
        private const val DECLINE_INCOMING_CALL_REQUEST_CODE = 4107
        private const val SCREEN_SHARE_REQUEST_CODE = 4108
    }
}
