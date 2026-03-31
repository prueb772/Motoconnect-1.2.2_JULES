package com.example.motoconnect

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL_NAME = "com.example.motoconnect/notifications"
    private val NOTIFICATION_ID = 75415
    private val NOTIFICATION_CHANNEL_ID = "geolocator_channel_01"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        crearCanalNotificacionUbicacion()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showTrackingNotification" -> {
                        showTrackingNotification()
                        result.success(null)
                    }
                    "hideTrackingNotification" -> {
                        hideTrackingNotification()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Muestra una notificación persistente que reemplaza la de geolocator.
     *
     * Usa el mismo ID (75415) y canal (geolocator_channel_01) que geolocator_android,
     * pero con flags adicionales para que no se pueda deslizar:
     * - FLAG_NO_CLEAR: evita que el usuario la limpie
     * - FLAG_ONGOING_EVENT: marca como evento en curso
     */
    private fun showTrackingNotification() {
        val notificationManager = getSystemService(NotificationManager::class.java)

        // Intent para abrir la app al tocar la notificación
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("MotoConnect - Ubicación activa")
            .setContentText("Compartiendo ubicación en tiempo real")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setAutoCancel(false)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(pendingIntent)
            .build()

        // Agregar flags adicionales de persistencia
        notification.flags = notification.flags or
                Notification.FLAG_NO_CLEAR or
                Notification.FLAG_ONGOING_EVENT

        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    /**
     * Detiene el foreground service de geolocator y cancela la notificación de tracking.
     *
     * Problema: notificationManager.cancel() no puede cancelar una notificación mientras
     * el foreground service que la creó sigue en ejecución. Por eso primero detenemos
     * el servicio (lo que llama stopForeground() internamente), y luego cancelamos.
     * Un segundo cancel diferido actúa como red de seguridad para la carrera async.
     */
    private fun hideTrackingNotification() {
        // Detener el foreground service de geolocator para que libere la notificación
        try {
            stopService(
                Intent().setClassName(
                    packageName,
                    "com.baseflow.geolocator.GeolocatorLocationService"
                )
            )
        } catch (_: Exception) { }

        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.cancel(NOTIFICATION_ID)

        // Cancel diferido: red de seguridad por si stopForeground() aún no completó
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            notificationManager.cancel(NOTIFICATION_ID)
        }, 1000)
    }

    /**
     * Pre-crea el canal de notificación que usa geolocator_android para el foreground service.
     *
     * geolocator_android crea el canal "geolocator_channel_01" con IMPORTANCE_NONE,
     * lo que hace la notificación invisible. Al pre-crearlo con IMPORTANCE_LOW,
     * la llamada posterior de geolocator es un no-op y la notificación se muestra.
     *
     * Para instalaciones existentes donde el canal ya tiene IMPORTANCE_NONE,
     * se elimina y se recrea con IMPORTANCE_LOW.
     */
    private fun crearCanalNotificacionUbicacion() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val channelId = NOTIFICATION_CHANNEL_ID

            // Si el canal ya existe con IMPORTANCE_NONE, eliminarlo para recrear
            val existing = manager.getNotificationChannel(channelId)
            if (existing != null && existing.importance == NotificationManager.IMPORTANCE_NONE) {
                manager.deleteNotificationChannel(channelId)
            }

            // Canal de ubicación en segundo plano (IMPORTANCE_LOW → visible sin sonido)
            val channel = NotificationChannel(
                channelId,
                "Ubicación en segundo plano",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Notificación activa mientras se comparte ubicación en sesiones de grupo"
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)

            // Canal de eventos (IMPORTANCE_HIGH → heads-up notification con sonido)
            val eventChannel = NotificationChannel(
                "eventos_channel",
                "Eventos MotoConnect",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notificaciones de nuevos eventos y recordatorios"
                setShowBadge(true)
            }
            manager.createNotificationChannel(eventChannel)

            // Canal de sesiones grupales (IMPORTANCE_HIGH → heads-up notification con sonido)
            val sessionChannel = NotificationChannel(
                "sesiones_channel",
                "Sesiones Grupales",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notificaciones de sesiones de ruta en grupo"
                setShowBadge(true)
            }
            manager.createNotificationChannel(sessionChannel)
        }
    }
}
