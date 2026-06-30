package com.example.chat_app.remotecontrol

import android.accessibilityservice.AccessibilityService
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

        fun tap(x: Float, y: Float): Boolean {
            val path = Path().apply { moveTo(x, y) }
            return dispatch(path, 0L, 80L)
        }

        fun swipe(
            startX: Float,
            startY: Float,
            endX: Float,
            endY: Float,
            durationMs: Long,
        ): Boolean {
            val path = Path().apply {
                moveTo(startX, startY)
                lineTo(endX, endY)
            }
            return dispatch(path, 0L, durationMs.coerceAtLeast(1L))
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

        private fun dispatch(path: Path, startTimeMs: Long, durationMs: Long): Boolean {
            val service = instance ?: return false
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, startTimeMs, durationMs))
                .build()
            return service.dispatchGesture(gesture, null, null)
        }
    }
}
