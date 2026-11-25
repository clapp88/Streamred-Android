package com.streamred.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Rational

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.streamred.app/pip"
    private var channel: MethodChannel? = null
    private var autoPip = false
    private var pipWidth = 16
    private var pipHeight = 9

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPip" -> {
                    val w = call.argument<Int>("width") ?: 16
                    val h = call.argument<Int>("height") ?: 9
                    result.success(enterPip(w, h))
                }
                "setAutoPip" -> {
                    autoPip = call.argument<Boolean>("enabled") ?: false
                    pipWidth = call.argument<Int>("width") ?: 16
                    pipHeight = call.argument<Int>("height") ?: 9
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun enterPip(width: Int, height: Int): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        var num = if (width > 0) width else 16
        var den = if (height > 0) height else 9
        val ratio = num.toDouble() / den.toDouble()
        if (ratio > 2.39) {
            num = 239
            den = 100
        } else if (ratio < 0.5) {
            num = 1
            den = 2
        }
        val params = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(num, den))
            .build()
        return try {
            enterPictureInPictureMode(params)
        } catch (e: Exception) {
            false
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (autoPip) enterPip(pipWidth, pipHeight)
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        channel?.invokeMethod("pipChanged", isInPictureInPictureMode)
    }
}
