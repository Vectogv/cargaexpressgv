package com.example.cargaexpress

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        crearCanalUbicacion()
    }

    // El servicio de ubicación del conductor (flutter_background_service) publica
    // su notificación en el canal 'location_service'. Si el canal no existe,
    // Android 8+ rechaza la notificación y cierra la app al conectarse
    // ("Bad notification for startForeground"). Los canales persisten, así que
    // también sirve cuando el servicio se reinicia sin la actividad.
    private fun crearCanalUbicacion() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val canal = NotificationChannel(
            "location_service",
            "Ubicación del conductor",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Aviso mientras CargaExpress comparte tu ubicación con el cliente"
            setShowBadge(false)
        }
        manager.createNotificationChannel(canal)
    }
}
