package com.ligolabs.pausepump

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/**
 * Service de premier plan affichant une notification persistante dont le
 * **chronomètre est rendu nativement par Android** (setChronometerCountDown) :
 * le compte à rebours défile tout seul, sans qu'aucun code Dart ne tourne.
 * C'est la technique des apps natives type "Gym Rest Timer".
 */
class TimerService : Service() {
    companion object {
        const val CHANNEL_ID = "pausepump_timer_ongoing"
        const val NOTIF_ID = 42
        const val ACTION_START = "com.ligolabs.pausepump.START"
        const val ACTION_STOP = "com.ligolabs.pausepump.STOP"
        const val EXTRA_END = "endTime"
        const val EXTRA_TITLE = "title"
        const val EXTRA_LABEL = "label"
    }

    override fun onBind(intent: Intent?) = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForegroundCompat()
            stopSelf()
            return START_NOT_STICKY
        }
        val end = intent?.getLongExtra(EXTRA_END, 0L) ?: 0L
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "PausePump"
        val label = intent?.getStringExtra(EXTRA_LABEL) ?: ""
        // Passage en premier plan protégé : sur Android 12+, un FGS refusé
        // (démarrage depuis l'arrière-plan, restriction OEM/type, permission
        // révoquée…) lève une exception SUR LE THREAD NATIF — non rattrapable
        // côté Dart. Le service n'est qu'un confort (chrono natif) : le timer
        // tourne de toute façon via le ticker Dart + la notif planifiée. On
        // dégrade donc en silence plutôt que de faire planter l'app.
        try {
            ServiceCompat.startForeground(
                this,
                NOTIF_ID,
                buildNotification(title, label, end),
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                } else {
                    0
                },
            )
        } catch (e: Exception) {
            Log.w("TimerService", "startForeground refusé : ${e.message}")
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    private fun buildNotification(title: String, label: String, endTime: Long): Notification {
        createChannel()
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = PendingIntent.getActivity(
            this, 0, launch,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_timer)
            .setContentTitle(title)
            .setContentText(label)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setContentIntent(contentIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        // Compte à rebours natif : Android fait défiler le temps jusqu'à `endTime`.
        if (endTime > 0L) {
            builder.setWhen(endTime)
                .setUsesChronometer(true)
                .setChronometerCountDown(true)
                .setShowWhen(true)
        }
        return builder.build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = getSystemService(NotificationManager::class.java)
            if (mgr.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Minuteur en cours",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = "Affiche le décompte de la pause/effort en cours"
                    setShowBadge(false)
                }
                mgr.createNotificationChannel(channel)
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            stopForeground(true)
        }
    }
}
