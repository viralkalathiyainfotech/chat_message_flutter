package com.example.chat_app.call

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

class CallForegroundService : Service() {
    private lateinit var notificationHelper: CallNotificationHelper

    override fun onCreate() {
        super.onCreate()
        notificationHelper = CallNotificationHelper(this)
        notificationHelper.createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_SHOW, null -> showNotification(intent)
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun showNotification(intent: Intent?) {
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Ongoing call"
        val body = intent?.getStringExtra(EXTRA_BODY) ?: "Tap to return to call"
        val isVideo = intent?.getBooleanExtra(EXTRA_IS_VIDEO, false) ?: false
        val isMicEnabled = intent?.getBooleanExtra(EXTRA_IS_MIC_ENABLED, true) ?: true
        val isCameraEnabled = intent?.getBooleanExtra(EXTRA_IS_CAMERA_ENABLED, true) ?: true
        val isScreenSharing = intent?.getBooleanExtra(EXTRA_IS_SCREEN_SHARING, false) ?: false
        val notification = notificationHelper.buildOngoingCallNotification(
            title = title,
            body = body,
            isVideo = isVideo,
            isMicEnabled = isMicEnabled,
            isCameraEnabled = isCameraEnabled,
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            var serviceType = ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            if (isVideo) {
                serviceType = serviceType or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
            }
            if (isScreenSharing) {
                serviceType = serviceType or ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            }
            startForeground(CallNotificationHelper.CALL_NOTIFICATION_ID, notification, serviceType)
        } else {
            startForeground(CallNotificationHelper.CALL_NOTIFICATION_ID, notification)
        }
    }

    companion object {
        const val ACTION_SHOW = "com.example.chat_app.call.action.SHOW"
        const val ACTION_STOP = "com.example.chat_app.call.action.STOP"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_IS_VIDEO = "isVideo"
        const val EXTRA_IS_MIC_ENABLED = "isMicEnabled"
        const val EXTRA_IS_CAMERA_ENABLED = "isCameraEnabled"
        const val EXTRA_IS_SCREEN_SHARING = "isScreenSharing"
    }
}
