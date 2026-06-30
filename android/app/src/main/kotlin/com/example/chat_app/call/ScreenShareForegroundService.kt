package com.example.chat_app.call

import android.app.Notification
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

class ScreenShareForegroundService : Service() {
    private lateinit var notificationHelper: CallNotificationHelper

    override fun onCreate() {
        super.onCreate()
        created = true
        notificationHelper = CallNotificationHelper(this)
        notificationHelper.createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        started = true
        when (intent?.action) {
            ACTION_STOP -> {
                active = false
                started = false
                lastStartError = null
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
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Screen sharing"
        val body = intent?.getStringExtra(EXTRA_BODY) ?: "Your screen is being shared"
        val requestId = intent?.getLongExtra(EXTRA_REQUEST_ID, 0L) ?: 0L
        activeRequestId = requestId
        active = false
        lastStartError = null
        val notification = notificationHelper.buildScreenShareNotification(
            title = title,
            body = body,
        )

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    SCREEN_SHARE_NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION,
                )
            } else {
                startForeground(SCREEN_SHARE_NOTIFICATION_ID, notification)
            }
            active = true
            lastStartError = null
        } catch (e: SecurityException) {
            failStart("Media projection foreground service was not allowed", e)
        } catch (e: IllegalArgumentException) {
            failStart("Media projection foreground service type was rejected", e)
        } catch (e: RuntimeException) {
            failStart("Unable to start media projection foreground service", e)
        }
    }

    private fun failStart(message: String, error: Throwable) {
        Log.w(TAG, message, error)
        active = false
        lastStartError = error.message ?: message
        stopSelf()
    }

    companion object {
        const val ACTION_SHOW = "com.example.chat_app.call.action.SCREEN_SHARE_SHOW"
        const val ACTION_STOP = "com.example.chat_app.call.action.SCREEN_SHARE_STOP"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_REQUEST_ID = "requestId"
        const val SCREEN_SHARE_NOTIFICATION_ID = 42042
        private const val TAG = "ScreenShareForeground"

        @Volatile
        var created: Boolean = false
            private set

        @Volatile
        var started: Boolean = false
            private set

        @Volatile
        var active: Boolean = false
            private set

        @Volatile
        var activeRequestId: Long = 0
            private set

        @Volatile
        var lastStartError: String? = null

        fun resetForStart(requestId: Long) {
            created = false
            started = false
            active = false
            activeRequestId = requestId
            lastStartError = null
        }
    }
}
