package com.example.chat_app

import android.app.PictureInPictureParams
import android.app.PendingIntent
import android.app.RemoteAction
import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.Rational
import android.view.WindowManager
import com.example.chat_app.call.CallForegroundService
import com.example.chat_app.call.CallNotificationHelper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var isActiveVideoCall = false
    private var isMicEnabled = true
    private var isCameraEnabled = true
    private var pipChannel: MethodChannel? = null
    private var notificationChannel: MethodChannel? = null
    private var hasPendingOpenCall = false
    private var pendingOpenCallAttempts = 0
    private val mainHandler = Handler(Looper.getMainLooper())
    private val callNotificationHelper by lazy { CallNotificationHelper(this) }

    private val callActionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_ANSWER_CALL -> answerIncomingCall()
                ACTION_DECLINE_CALL -> declineIncomingCall()
                ACTION_HANGUP_CALL -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isInPictureInPictureMode) {
                        pipChannel?.invokeMethod("hangupCall", null)
                            ?: notificationChannel?.invokeMethod("hangupCall", null)
                    } else {
                        notificationChannel?.invokeMethod("hangupCall", null)
                            ?: pipChannel?.invokeMethod("hangupCall", null)
                    }
                    closePipIfNeeded()
                }
                ACTION_TOGGLE_MIC -> invokeCallControl("toggleAudio")
                ACTION_TOGGLE_CAMERA -> invokeCallControl("toggleVideo")
                ACTION_OPEN_CALL -> openCallScreen()
                ACTION_OPEN_INCOMING_CALL -> openIncomingCallScreen()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        applyIncomingCallWindowFlagsIfNeeded(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "setCallActive" -> {
                        val args = call.arguments as? Map<*, *>
                        isActiveVideoCall = args?.get("active") as? Boolean
                            ?: call.arguments as? Boolean
                                ?: false
                        isMicEnabled = args?.get("audioEnabled") as? Boolean ?: true
                        isCameraEnabled = args?.get("videoEnabled") as? Boolean ?: true
                        if (isActiveVideoCall) {
                            updatePipParams()
                        }
                        if (!isActiveVideoCall) {
                            it.invokeMethod("onPipModeChanged", false)
                        }
                        result.success(null)
                        if (!isActiveVideoCall) {
                            closePipIfNeeded()
                        }
                    }
                    "enterPip" -> {
                        result.success(enterPipIfAllowed())
                    }
                    "updateCallControls" -> {
                        val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                        isMicEnabled = args["audioEnabled"] as? Boolean ?: isMicEnabled
                        isCameraEnabled = args["videoEnabled"] as? Boolean ?: isCameraEnabled
                        updatePipParams()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        notificationChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL).also {
                it.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "showOngoingCall" -> {
                            val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                            showOngoingCall(
                                title = args["title"] as? String ?: "Ongoing call",
                                body = args["body"] as? String ?: "Tap to return to call",
                                isVideo = args["isVideo"] as? Boolean ?: false,
                                isMicEnabled = args["audioEnabled"] as? Boolean ?: true,
                                isCameraEnabled = args["videoEnabled"] as? Boolean ?: true,
                                isScreenSharing = args["isScreenSharing"] as? Boolean ?: false,
                            )
                            result.success(null)
                        }
                        "stopOngoingCall" -> {
                            stopOngoingCall()
                            result.success(null)
                        }
                        "showIncomingCall" -> {
                            val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                            showIncomingCall(
                                title = args["title"] as? String ?: "Incoming call",
                                body = args["body"] as? String ?: "Tap to answer",
                                callerName = args["callerName"] as? String ?: "Unknown caller",
                                isVideo = args["isVideo"] as? Boolean ?: false,
                            )
                            result.success(null)
                        }
                        "stopIncomingCall" -> {
                            stopIncomingCall()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                }
            }

        registerCallActionReceiver()
        handleCallIntent(intent)
        if (hasPendingOpenCall) {
            scheduleOpenCallScreen()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        applyIncomingCallWindowFlagsIfNeeded(intent)
        setIntent(intent)
        handleCallIntent(intent)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (isActiveVideoCall) {
            enterPipIfAllowed()
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipChannel?.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
    }

    override fun onDestroy() {
        runCatching { unregisterReceiver(callActionReceiver) }
        super.onDestroy()
    }

    private fun registerCallActionReceiver() {
        val filter = IntentFilter().apply {
            addAction(ACTION_ANSWER_CALL)
            addAction(ACTION_DECLINE_CALL)
            addAction(ACTION_HANGUP_CALL)
            addAction(ACTION_TOGGLE_MIC)
            addAction(ACTION_TOGGLE_CAMERA)
            addAction(ACTION_OPEN_CALL)
            addAction(ACTION_OPEN_INCOMING_CALL)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(callActionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(callActionReceiver, filter)
        }
    }

    private fun handleCallIntent(intent: Intent?) {
        when (intent?.action) {
            ACTION_OPEN_CALL -> {
                hasPendingOpenCall = true
                pendingOpenCallAttempts = 0
                openCallScreen()
            }
            ACTION_OPEN_INCOMING_CALL -> openIncomingCallScreen()
            ACTION_ANSWER_CALL -> answerIncomingCall()
            ACTION_DECLINE_CALL -> declineIncomingCall()
        }
    }

    private fun openCallScreen() {
        val channel = notificationChannel
        if (channel == null) {
            hasPendingOpenCall = true
        } else {
            channel.invokeMethod(
                "openCallScreen",
                null,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        hasPendingOpenCall = false
                        pendingOpenCallAttempts = 0
                    }

                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        retryOpenCallScreen()
                    }

                    override fun notImplemented() {
                        retryOpenCallScreen()
                    }
                },
            )
        }
    }

    private fun openIncomingCallScreen() {
        notificationChannel?.invokeMethod("openIncomingCallScreen", null)
    }

    private fun openIncomingCallActivity() {
        val intent = Intent(this, MainActivity::class.java).apply {
            action = ACTION_OPEN_INCOMING_CALL
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        applyIncomingCallWindowFlagsIfNeeded(intent)
        bringCurrentTaskToFront()
        runCatching {
            startActivity(intent)
        }.onFailure {
            Log.w("MainActivity", "Unable to launch incoming call screen directly", it)
            openIncomingCallScreen()
        }
        mainHandler.postDelayed({ openIncomingCallScreen() }, INCOMING_CALL_OPEN_DELAY_MS)
    }

    private fun bringCurrentTaskToFront() {
        runCatching {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            activityManager.moveTaskToFront(taskId, ActivityManager.MOVE_TASK_WITH_HOME)
        }.onFailure {
            Log.w("MainActivity", "Unable to move call task to front", it)
        }
    }

    private fun answerIncomingCall() {
        stopIncomingCall()
        notificationChannel?.invokeMethod("answerIncomingCall", null)
    }

    private fun declineIncomingCall() {
        stopIncomingCall()
        notificationChannel?.invokeMethod("declineIncomingCall", null)
    }

    private fun retryOpenCallScreen() {
        hasPendingOpenCall = true
        if (pendingOpenCallAttempts >= MAX_OPEN_CALL_ATTEMPTS) {
            Log.w("MainActivity", "Unable to deliver openCallScreen to Flutter")
            return
        }
        pendingOpenCallAttempts += 1
        scheduleOpenCallScreen()
    }

    private fun scheduleOpenCallScreen() {
        mainHandler.postDelayed({ openCallScreen() }, OPEN_CALL_RETRY_DELAY_MS)
    }

    private fun invokeCallControl(method: String) {
        pipChannel?.invokeMethod(method, null) ?: notificationChannel?.invokeMethod(method, null)
    }

    private fun enterPipIfAllowed(): Boolean {
        if (!isActiveVideoCall || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        if (isInPictureInPictureMode) return true
        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)) {
            Log.w("MainActivity", "Device does not support PiP")
            return false
        }
        if (isFinishing || isDestroyed) return false

        return runCatching {
            enterPictureInPictureMode(buildPipParams())
        }.onFailure {
            Log.e("MainActivity", "Unable to enter PiP", it)
        }.getOrDefault(false)
    }

    private fun updatePipParams() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        runCatching {
            setPictureInPictureParams(buildPipParams())
        }.onFailure {
            Log.e("MainActivity", "Unable to update PiP params", it)
        }
    }

    private fun buildPipParams(): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(9, 16))
            .setActions(buildPipActions())
        return builder.build()
    }

    private fun buildPipActions(): List<RemoteAction> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return emptyList()
        return listOf(
            buildPipAction(
                action = ACTION_TOGGLE_MIC,
                iconRes = if (isMicEnabled) R.drawable.ic_pip_mic_24 else R.drawable.ic_pip_mic_off_24,
                title = if (isMicEnabled) "Mute" else "Unmute",
            ),
            buildPipAction(
                action = ACTION_HANGUP_CALL,
                iconRes = R.drawable.ic_pip_call_end_24,
                title = "End",
            ),
            buildPipAction(
                action = ACTION_TOGGLE_CAMERA,
                iconRes = if (isCameraEnabled) {
                    R.drawable.ic_pip_videocam_24
                } else {
                    R.drawable.ic_pip_videocam_off_24
                },
                title = if (isCameraEnabled) "Stop video" else "Start video",
            ),
        )
    }

    private fun buildPipAction(action: String, iconRes: Int, title: String): RemoteAction {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val intent = Intent(action).setPackage(packageName)
        val pendingIntent = PendingIntent.getBroadcast(this, action.hashCode(), intent, flags)
        return RemoteAction(
            Icon.createWithResource(this, iconRes),
            title,
            title,
            pendingIntent,
        )
    }

    private fun closePipIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        if (isInPictureInPictureMode && !isFinishing) {
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            startActivity(intent)
        }
    }

    private fun applyIncomingCallWindowFlagsIfNeeded(intent: Intent?) {
        val action = intent?.action
        if (action != ACTION_OPEN_INCOMING_CALL && action != ACTION_ANSWER_CALL) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            )
        }
    }

    private fun clearIncomingCallWindowFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(false)
            setTurnScreenOn(false)
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            @Suppress("DEPRECATION")
            window.clearFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            )
        }
    }

    private fun showOngoingCall(
        title: String,
        body: String,
        isVideo: Boolean,
        isMicEnabled: Boolean,
        isCameraEnabled: Boolean,
        isScreenSharing: Boolean,
    ) {
        this.isMicEnabled = isMicEnabled
        this.isCameraEnabled = isCameraEnabled
        val serviceIntent = Intent(this, CallForegroundService::class.java).apply {
            action = CallForegroundService.ACTION_SHOW
            putExtra(CallForegroundService.EXTRA_TITLE, title)
            putExtra(CallForegroundService.EXTRA_BODY, body)
            putExtra(CallForegroundService.EXTRA_IS_VIDEO, isVideo)
            putExtra(CallForegroundService.EXTRA_IS_MIC_ENABLED, isMicEnabled)
            putExtra(CallForegroundService.EXTRA_IS_CAMERA_ENABLED, isCameraEnabled)
            putExtra(CallForegroundService.EXTRA_IS_SCREEN_SHARING, isScreenSharing)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun showIncomingCall(
        title: String,
        body: String,
        callerName: String,
        isVideo: Boolean,
    ) {
        callNotificationHelper.createNotificationChannel()
        callNotificationHelper.showIncomingCallNotification(
            title = title,
            body = body,
            callerName = callerName,
            isVideo = isVideo,
        )
        mainHandler.post { openIncomingCallActivity() }
    }

    private fun stopOngoingCall() {
        val serviceIntent = Intent(this, CallForegroundService::class.java).apply {
            action = CallForegroundService.ACTION_STOP
        }
        startService(serviceIntent)
    }

    private fun stopIncomingCall() {
        callNotificationHelper.cancelIncomingCallNotification()
        clearIncomingCallWindowFlags()
    }

    companion object {
        private const val PIP_CHANNEL = "app.call/pip"
        private const val NOTIFICATION_CHANNEL = "app.call/notification"
        const val ACTION_ANSWER_CALL = "com.example.chat_app.action.ANSWER_CALL"
        const val ACTION_DECLINE_CALL = "com.example.chat_app.action.DECLINE_CALL"
        const val ACTION_HANGUP_CALL = "com.example.chat_app.action.HANGUP_CALL"
        const val ACTION_TOGGLE_MIC = "com.example.chat_app.action.TOGGLE_MIC"
        const val ACTION_TOGGLE_CAMERA = "com.example.chat_app.action.TOGGLE_CAMERA"
        const val ACTION_OPEN_CALL = "com.example.chat_app.action.OPEN_CALL"
        const val ACTION_OPEN_INCOMING_CALL = "com.example.chat_app.action.OPEN_INCOMING_CALL"
        private const val OPEN_CALL_RETRY_DELAY_MS = 300L
        private const val INCOMING_CALL_OPEN_DELAY_MS = 120L
        private const val MAX_OPEN_CALL_ATTEMPTS = 10
    }
}
