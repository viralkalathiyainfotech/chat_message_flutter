package com.example.chat_app.call

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

class CallForegroundService : Service() {
    private lateinit var notificationHelper: CallNotificationHelper

    override fun onCreate() {
        super.onCreate()
        notificationHelper = CallNotificationHelper(this)
        notificationHelper.createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            lastForegroundStartError = "CallForegroundService reached onStartCommand but did not start foreground yet"
            when (intent?.action) {
                ACTION_STOP -> {
                    activeForegroundServiceType = 0
                    lastForegroundStartError = null
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                    return START_NOT_STICKY
                }
                ACTION_SHOW, null -> showNotification(intent)
            }
        } catch (e: Throwable) {
            Log.e(TAG, "Call foreground service failed in onStartCommand", e)
            activeForegroundServiceType = 0
            lastForegroundStartError = e.message ?: e.javaClass.simpleName
            stopSelf()
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
            var callServiceType = ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            if (isVideo) {
                callServiceType = callServiceType or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
            }

            val serviceType = if (isScreenSharing) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            } else {
                callServiceType
            }
            if (isScreenSharing) {
                startForegroundSafely(notification, serviceType, callServiceType)
            } else {
                startForeground(CallNotificationHelper.CALL_NOTIFICATION_ID, notification, serviceType)
                activeForegroundServiceType = serviceType
                lastForegroundStartError = null
            }
        } else {
            startForeground(CallNotificationHelper.CALL_NOTIFICATION_ID, notification)
            activeForegroundServiceType = 0
            lastForegroundStartError = null
        }
    }

    private fun startForegroundSafely(
        notification: android.app.Notification,
        requestedServiceType: Int,
        fallbackServiceType: Int,
    ) {
        try {
            startForeground(
                CallNotificationHelper.CALL_NOTIFICATION_ID,
                notification,
                requestedServiceType,
            )
            activeForegroundServiceType = requestedServiceType
            lastForegroundStartError = null
        } catch (e: SecurityException) {
            Log.w(TAG, "Media projection foreground service was not allowed; keeping call notification active", e)
            lastForegroundStartError = e.message
            startForeground(
                CallNotificationHelper.CALL_NOTIFICATION_ID,
                notification,
                fallbackServiceType,
            )
            activeForegroundServiceType = fallbackServiceType
        } catch (e: IllegalArgumentException) {
            Log.w(TAG, "Media projection foreground service type was rejected; keeping call notification active", e)
            lastForegroundStartError = e.message
            startForeground(
                CallNotificationHelper.CALL_NOTIFICATION_ID,
                notification,
                fallbackServiceType,
            )
            activeForegroundServiceType = fallbackServiceType
        } catch (e: RuntimeException) {
            Log.w(TAG, "Unable to start media projection foreground service; keeping call notification active", e)
            lastForegroundStartError = e.message
            runCatching {
                startForeground(
                    CallNotificationHelper.CALL_NOTIFICATION_ID,
                    notification,
                    fallbackServiceType,
                )
                activeForegroundServiceType = fallbackServiceType
            }.onFailure {
                Log.w(TAG, "Unable to start fallback call foreground service", it)
                activeForegroundServiceType = 0
            }
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
        private const val TAG = "CallForegroundService"

        @Volatile
        var activeForegroundServiceType: Int = 0
            private set

        @Volatile
        var lastForegroundStartError: String? = null
            private set

        fun resetMediaProjectionStart() {
            activeForegroundServiceType = 0
            lastForegroundStartError = null
        }

        fun markMediaProjectionStartError(message: String?) {
            activeForegroundServiceType = 0
            lastForegroundStartError = message
        }

        fun isMediaProjectionForegroundActive(): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return true
            return activeForegroundServiceType and
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION != 0
        }
    }
}
