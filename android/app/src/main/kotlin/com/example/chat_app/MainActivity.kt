package com.example.chat_app

import android.app.PictureInPictureParams
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.util.Rational
import com.example.chat_app.call.CallForegroundService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var isActiveVideoCall = false
    private var notificationChannel: MethodChannel? = null
    private var hasPendingOpenCall = false

    private val callActionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_HANGUP_CALL -> notificationChannel?.invokeMethod("hangupCall", null)
                ACTION_OPEN_CALL -> openCallScreen()
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setCallActive" -> {
                        isActiveVideoCall = call.arguments as? Boolean ?: false
                        result.success(null)
                    }
                    "enterPip" -> {
                        enterPipIfAllowed()
                        result.success(null)
                    }
                    else -> result.notImplemented()
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
                            )
                            result.success(null)
                        }
                        "stopOngoingCall" -> {
                            stopOngoingCall()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                }
            }

        registerCallActionReceiver()
        handleCallIntent(intent)
        if (hasPendingOpenCall) {
            openCallScreen()
            hasPendingOpenCall = false
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleCallIntent(intent)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        enterPipIfAllowed()
    }

    override fun onDestroy() {
        runCatching { unregisterReceiver(callActionReceiver) }
        super.onDestroy()
    }

    private fun registerCallActionReceiver() {
        val filter = IntentFilter().apply {
            addAction(ACTION_HANGUP_CALL)
            addAction(ACTION_OPEN_CALL)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(callActionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(callActionReceiver, filter)
        }
    }

    private fun handleCallIntent(intent: Intent?) {
        if (intent?.action == ACTION_OPEN_CALL) {
            openCallScreen()
        }
    }

    private fun openCallScreen() {
        val channel = notificationChannel
        if (channel == null) {
            hasPendingOpenCall = true
        } else {
            channel.invokeMethod("openCallScreen", null)
        }
    }

    private fun enterPipIfAllowed() {
        if (!isActiveVideoCall || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val params = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(9, 16))
            .build()
        enterPictureInPictureMode(params)
    }

    private fun showOngoingCall(title: String, body: String, isVideo: Boolean) {
        val serviceIntent = Intent(this, CallForegroundService::class.java).apply {
            action = CallForegroundService.ACTION_SHOW
            putExtra(CallForegroundService.EXTRA_TITLE, title)
            putExtra(CallForegroundService.EXTRA_BODY, body)
            putExtra(CallForegroundService.EXTRA_IS_VIDEO, isVideo)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun stopOngoingCall() {
        val serviceIntent = Intent(this, CallForegroundService::class.java).apply {
            action = CallForegroundService.ACTION_STOP
        }
        startService(serviceIntent)
    }

    companion object {
        private const val PIP_CHANNEL = "app.call/pip"
        private const val NOTIFICATION_CHANNEL = "app.call/notification"
        const val ACTION_HANGUP_CALL = "com.example.chat_app.action.HANGUP_CALL"
        const val ACTION_OPEN_CALL = "com.example.chat_app.action.OPEN_CALL"
    }
}
