# Configurar Firebase FCM en Flutter

## 1. Crear el proyecto en Firebase

- Entrar a https://console.firebase.google.com
- Crear un proyecto llamado **Carga Express GV**.
- Agregar una aplicación Android.

**Nombre del paquete Android:**

```
com.example.cargaexpress
```

**Proyecto Firebase:**

| Campo | Valor |
|---|---|
| Project ID | `app-cargaexpress` |
| Project number | `848686850284` |
| Storage bucket | `app-cargaexpress.firebasestorage.app` |
| API Key | `AIzaSyCQPBGK0CuoidlFBewtH7Fk2C8Als1kwII` |
| App ID | `1:848686850284:android:d5c68a1b3b489b813d45c9` |

Archivo `google-services.json` copiado en:

```
android/app/google-services.json ✅
```

## 2. Agregar dependencias

En `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  firebase_core: ^4.0.0
  firebase_messaging: ^16.0.0
```

Ejecutar:

```bash
flutter pub get
```

## 3. Configurar Android

En `android/app/build.gradle.kts`:

```kotlin
plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}
```

## 4. Inicializar Firebase

En `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MyApp());
}
```

## 5. Obtener el token del dispositivo

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> obtenerToken() async {
  String? token = await FirebaseMessaging.instance.getToken();

  print("TOKEN:");
  print(token);
}
```

Guardar ese token en PostgreSQL mediante AdonisJS.

## 6. Crear credenciales para el backend

En Firebase:

**Configuración del proyecto → Cuentas de servicio → Generar nueva clave privada.**

Se descargará un archivo JSON.

Guardar las variables de ese JSON en Railway para que AdonisJS pueda enviar notificaciones.

## Arquitectura final

```
Flutter
↓
AdonisJS (Railway)
↓
Firebase Cloud Messaging
↓
Celular del usuario
```

## Ejemplos de notificaciones

- Nuevo viaje disponible.
- Oferta aceptada.
- Mensaje nuevo.
- Viaje completado.
- Pago recibido.

---

## 7. Backend con AdonisJS — Enviar notificaciones FCM

> **✅ El backend ya está completamente implementado y configurado.**

### Estado actual del backend (`D:\cargaexpressbakend`)

| Componente | Archivo | Estado |
|---|---|---|
| Modelo `fcmToken` | `app/models/user.ts:44` | ✅ |
| Endpoint para registrar token | `PUT /api/users/fcm-token` en `app/controllers/profile_controller.ts:130` | ✅ |
| Servicio de notificaciones | `app/services/push_notification_service.ts` con `sendToToken` y `sendToMultiple` | ✅ |
| Llamadas existentes | Ofertas, viajes, emergencias, chat, moderador, admin | ✅ |
| Credenciales locales | `storage/firebase-credentials.json` | ✅ |
| `.env` local | `FIREBASE_CREDENTIALS_PATH=...` | ✅ |

### En Railway (producción)

No uses `FIREBASE_CREDENTIALS_PATH`. En Railway agrega la variable **`FIREBASE_CREDENTIALS_JSON`** con el JSON completo de la cuenta de servicio como valor. El `start.sh` lo escribe a disco automáticamente.

### Flujo completo

```
[Flutter] obtiene token → PUT /api/users/fcm-token (guarda en PostgreSQL)
       ↓
[AdonisJS] detecta evento (nuevo viaje, oferta, etc.)
       ↓
       llama a sendToToken(token, title, body) desde push_notification_service
       ↓
[Firebase FCM] entrega la notificación
       ↓
[Celular] recibe la notificación
```
