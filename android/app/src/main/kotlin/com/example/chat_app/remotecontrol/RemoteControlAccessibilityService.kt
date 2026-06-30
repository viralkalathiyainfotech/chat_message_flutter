package com.example.chat_app.remotecontrol

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityService.GestureResultCallback
import android.accessibilityservice.GestureDescription
import android.content.Context
import android.content.Intent
import android.graphics.Path
import android.os.Bundle
import android.provider.Settings
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityManager
import android.view.accessibility.AccessibilityNodeInfo

class RemoteControlAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        if (instance === this) {
            instance = null
        }
        super.onDestroy()
    }

    companion object {
        @Volatile
        private var instance: RemoteControlAccessibilityService? = null

        fun isServiceEnabled(context: Context): Boolean {
            if (instance != null) return true
            val manager = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
            val expectedId = "${context.packageName}/${RemoteControlAccessibilityService::class.java.name}"
            return manager.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_GENERIC)
                .any { it.id == expectedId }
        }

        fun openAccessibilitySettings(context: Context) {
            context.startActivity(
                Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }

        fun tap(x: Float, y: Float, onFinished: ((Boolean) -> Unit)? = null): Boolean {
            val service = instance ?: return false
            val point = service.toDisplayPoint(x, y)
            val path = Path().apply { moveTo(point.first, point.second) }
            return dispatch(path, 0L, 55L, onFinished)
        }

        fun swipe(
            startX: Float,
            startY: Float,
            endX: Float,
            endY: Float,
            durationMs: Long,
            onFinished: ((Boolean) -> Unit)? = null,
        ): Boolean {
            val service = instance ?: return false
            val start = service.toDisplayPoint(startX, startY)
            val end = service.toDisplayPoint(endX, endY)
            val path = Path().apply {
                moveTo(start.first, start.second)
                lineTo(end.first, end.second)
            }
            return dispatch(path, 0L, durationMs.coerceIn(80L, 550L), onFinished)
        }

        fun globalAction(action: String): Boolean {
            val service = instance ?: return false
            val globalAction = when (action) {
                "back" -> GLOBAL_ACTION_BACK
                "home" -> GLOBAL_ACTION_HOME
                "recents" -> GLOBAL_ACTION_RECENTS
                "notifications" -> GLOBAL_ACTION_NOTIFICATIONS
                "quickSettings" -> GLOBAL_ACTION_QUICK_SETTINGS
                else -> return false
            }
            return service.performGlobalAction(globalAction)
        }

        fun setFocusedText(text: String): Boolean {
            val node = instance?.rootInActiveWindow?.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
                ?: return false
            val args = Bundle().apply {
                putCharSequence(
                    AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                    text,
                )
            }
            return node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        }

        private fun dispatch(
            path: Path,
            startTimeMs: Long,
            durationMs: Long,
            onFinished: ((Boolean) -> Unit)? = null,
        ): Boolean {
            val service = instance ?: return false
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, startTimeMs, durationMs))
                .build()
            val callback = onFinished?.let {
                object : GestureResultCallback() {
                    override fun onCompleted(gestureDescription: GestureDescription?) {
                        it(true)
                    }

                    override fun onCancelled(gestureDescription: GestureDescription?) {
                        it(false)
                    }
                }
            }
            return service.dispatchGesture(gesture, callback, null)
        }
    }

    private fun toDisplayPoint(x: Float, y: Float): Pair<Float, Float> {
        val metrics = resources.displayMetrics
        val displayX = if (x in 0f..1f) x * metrics.widthPixels else x
        val displayY = if (y in 0f..1f) y * metrics.heightPixels else y
        return Pair(displayX, displayY)
    }
}
