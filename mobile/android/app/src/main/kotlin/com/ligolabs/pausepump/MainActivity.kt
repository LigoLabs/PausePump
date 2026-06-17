package com.ligolabs.pausepump

import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "pausepump/timer_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val intent = Intent(this, TimerService::class.java).apply {
                            action = TimerService.ACTION_START
                            putExtra(TimerService.EXTRA_END, (call.argument<Number>("endTime"))?.toLong() ?: 0L)
                            putExtra(TimerService.EXTRA_TITLE, call.argument<String>("title") ?: "PausePump")
                            putExtra(TimerService.EXTRA_LABEL, call.argument<String>("label") ?: "")
                        }
                        ContextCompat.startForegroundService(this, intent)
                        result.success(null)
                    }
                    "stop" -> {
                        val intent = Intent(this, TimerService::class.java).apply {
                            action = TimerService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
