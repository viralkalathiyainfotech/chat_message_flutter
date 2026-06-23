package com.example.chat_app.call

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.example.chat_app.MainActivity

class CallActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (
            action != MainActivity.ACTION_ANSWER_CALL &&
            action != MainActivity.ACTION_DECLINE_CALL &&
            action != MainActivity.ACTION_HANGUP_CALL &&
            action != MainActivity.ACTION_TOGGLE_MIC &&
            action != MainActivity.ACTION_TOGGLE_CAMERA
        ) {
            return
        }

        context.sendBroadcast(
            Intent(action).setPackage(context.packageName),
        )
    }
}
