package com.ligolabs.pausepump

import android.content.Intent
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.util.Log
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
                        // Android 12+ : démarrer un FGS depuis l'arrière-plan
                        // lève ForegroundServiceStartNotAllowedException ICI
                        // (au site d'appel). Le service n'est qu'un confort —
                        // on ne fait jamais planter l'app pour ça.
                        try {
                            ContextCompat.startForegroundService(this, intent)
                        } catch (e: Exception) {
                            Log.w("PausePump", "start FGS refusé : ${e.message}")
                        }
                        result.success(null)
                    }
                    "stop" -> {
                        val intent = Intent(this, TimerService::class.java).apply {
                            action = TimerService.ACTION_STOP
                        }
                        try {
                            startService(intent)
                        } catch (e: Exception) {
                            Log.w("PausePump", "stop FGS ignoré : ${e.message}")
                        }
                        result.success(null)
                    }
                    // Des écouteurs (Bluetooth, filaires, USB…) sont-ils
                    // branchés ? Sert à router le bip de fin : flux média
                    // (→ écouteurs) plutôt que notif sur le flux ALARME,
                    // qu'Android sort toujours du haut-parleur.
                    "hasHeadphones" -> {
                        val am = getSystemService(AUDIO_SERVICE) as AudioManager
                        val has = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS).any { d ->
                            d.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                                d.type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                                d.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
                                d.type == AudioDeviceInfo.TYPE_USB_HEADSET ||
                                d.type == AudioDeviceInfo.TYPE_HEARING_AID ||
                                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                                    d.type == AudioDeviceInfo.TYPE_BLE_HEADSET)
                        }
                        result.success(has)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
