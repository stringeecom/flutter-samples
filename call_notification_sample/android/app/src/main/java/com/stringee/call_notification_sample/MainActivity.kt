package com.stringee.call_notification_sample

import io.flutter.embedding.android.FlutterActivity
import android.app.KeyguardManager
import android.content.Context
import android.os.Build.VERSION
import android.os.Build.VERSION_CODES
import android.os.Bundle
import android.os.PersistableBundle
import android.view.WindowManager.LayoutParams


class MainActivity: FlutterActivity() {
    private var lock: KeyguardManager.KeyguardLock? = null

    override fun onCreate(savedInstanceState: Bundle?, persistentState: PersistableBundle?) {
        super.onCreate(savedInstanceState, persistentState)
        window.addFlags(
            LayoutParams.FLAG_SHOW_WHEN_LOCKED
                    or LayoutParams.FLAG_DISMISS_KEYGUARD
                    or LayoutParams.FLAG_TURN_SCREEN_ON
                    or LayoutParams.FLAG_KEEP_SCREEN_ON
        )
        val keyguardManager: KeyguardManager =
            getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        lock = keyguardManager.newKeyguardLock(KEYGUARD_SERVICE)
        lock?.disableKeyguard()
        if (VERSION.SDK_INT >= VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
    }
}

