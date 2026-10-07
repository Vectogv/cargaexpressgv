package co.cargaexpress.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        crearCanalUbicacion()
        crearCanalViajes()
    }

    // Canal de los avisos de viaje (push de Firebase): importancia alta y un
    // tono propio (res/raw/cargaexpress_aviso.wav). Es el canal por defecto
    // del manifiesto, así que lo usan las dos apps (cliente y conductor).
    // Android guarda el canal al crearlo: para cambiar el sonido después hay
    // que cambiar también el id del canal.
    private fun crearCanalViajes() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val sonido = Uri.parse("android.resource://$packageName/raw/cargaexpress_aviso")
        val atributos = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val canal = NotificationChannel(
            "cargaexpress_viajes",
            "Avisos de viajes",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Nuevos viajes cerca, ofertas y cambios de tu envío"
            setSound(sonido, atributos)
            enableVibration(true)
        }
        manager.createNotificationChannel(canal)
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
