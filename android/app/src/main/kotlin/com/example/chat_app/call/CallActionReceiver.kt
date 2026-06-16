package com.example.chat_app.call

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.example.chat_app.MainActivity

class CallActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != MainActivity.ACTION_HANGUP_CALL) return

        context.sendBroadcast(
            Intent(MainActivity.ACTION_HANGUP_CALL).setPackage(context.packageName),
        )
    }
}
