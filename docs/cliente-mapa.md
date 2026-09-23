# Mapa del cliente — CargaExpress (app Flutter)

> Actualizar este archivo cuando cambie una pantalla, endpoint o evento del cliente.

Alcance: lado **cliente** de `lib/` (más las pantallas compartidas de auth y notificaciones que usa). Backend de referencia (solo lectura): `C:\Users\automatacionsena\bakend-cargaexpress` (AdonisJS), rutas en `start/routes.ts`.

---

## 1. Configuración

### Base URL — `lib/core/environment.dart`

Orden de resolución de `Environment.baseUrl`:

1. `Environment.testBaseUrl` — solo para tests unitarios (`@visibleForTesting`).
2. `PRODUCTION_URL` vía `--dart-define=PRODUCTION_URL=...`, si no está vacío.
3. `TEST_MODE=true` (`--dart-define=TEST_MODE=true`) → `http://10.0.2.2:3333` (emulador Android → backend local).
4. Por defecto → Railway: `https://bakend-cargaexpress-production.up.railway.app`.

- `Environment.apiBaseUrl` = `baseUrl + '/api'`.
- `Environment.wsUrl` = `baseUrl` (mismo host para socket.io).
- CI (`.github/workflows/flutter.yml`, job `flutter build apk --release`) no define `PRODUCTION_URL` ni `TEST_MODE` → el APK de CI apunta a Railway.
- Cleartext HTTP (`usesCleartextTraffic="true"`) solo en `android/app/src/debug/AndroidManifest.xml`, para permitir `10.0.2.2` en debug; no existe en el manifest de release.

### Autenticación — `lib/services/api_client.dart` + `lib/services/api/http_client.dart`

- Tokens (`auth_token`, `auth_refresh_token`) y perfil (`auth_user_id`, `auth_nombre`, `auth_apellido`, `auth_email`, `auth_rol`, `auth_es_moderador`, `auth_zona_moderador`) se guardan en `SharedPreferences` (`ApiClient._saveTokens`/`saveProfile`).
- Peticiones con `auth: true` agregan `Authorization: Bearer <token>` (`HttpClient._headers`).
- **401** con `auth:true` → `HttpClient._execute` dispara una única renovación compartida (`refreshSessionShared()`, `Future<bool>? _refreshing` compartido entre peticiones concurrentes) y reintenta una vez. Si el refresh es rechazado explícitamente (400/401/422, `ApiClient.isRefreshRejection`) limpia la sesión y lanza `ApiException(code: 'SESION_EXPIRADA')`; errores transitorios (red/429/5xx) no cierran sesión.
- **403** `code == 'CUENTA_SUSPENDIDA'` → `HttpClient._checkSuspended` limpia tokens y emite `SessionEvents(suspended)`; `main.dart._onSessionEvent` navega a `AuthScreen` con `pushAndRemoveUntil` y muestra el motivo.
- Isolate de ubicación en segundo plano (`HttpClient.isBackgroundIsolate = true`): nunca refresca tokens (son de un solo uso y los rota el isolate principal); ante 401 relee `SharedPreferences` (`ApiClient.reloadTokens`) y reintenta una vez.
- Timeouts: 20 s peticiones normales, 60 s subidas (`uploadFile`); tamaño máx. de subida 5 MB (`defaultMaxUploadBytes`).
- `X-Idempotency-Key`: se agrega en POSTs con `idempotent: true` o `idempotencyKey` explícita (request, reserve, complete, finalize, confirm-close…). Una clave por acción de usuario, reutilizada en reintentos.

---

## 2. Navegación

No hay router (`go_router` / rutas nombradas): todo es `Navigator.push` / `pushReplacement` / `pushAndRemoveUntil` con `MaterialPageRoute` directo.

- **Raíz** (`lib/main.dart`, `MainApp.build`): `home: ApiClient.instance.token != null ? homeScreenFor(homeDestinoForSession()) : const AuthScreen()`.
- **Ruteo por rol** (`lib/screens/home_by_role.dart`): `HomeDestino` (`admin | moderador | conductor | cliente | ninguno`) se calcula con `homeDestinoFor({rol, esModerador})`; `homeScreenFor(destino)` mapea a la pantalla de inicio (cliente → `ClienteHomeScreen`, es decir `lib/screens/cliente/home_screen.dart`). La usan login, registro y la recuperación de sesión en frío (`main.dart:_homeScreenByRole`), para que el mismo usuario siempre llegue al mismo inicio.
- `abrirInicioComoRaiz(context, home)` — usado tras login y registro: hace `pushAndRemoveUntil` para dejar el Home como única ruta de la pila (si no, `AuthScreen` quedaba debajo y cualquier `popUntil(isFirst)` volvía al login).
- Patrón "volver al inicio" en las pantallas del viaje: `Navigator.of(context).popUntil((route) => route.isFirst)`.

---

## 3. Pantallas — `lib/screens/cliente/*` (+ auth y notificaciones compartidas)

| Archivo | Para qué | Se abre desde | Lleva a | Endpoints/eventos | Test |
|---|---|---|---|---|---|
| `ajustes_screen.dart` | Preferencias de notificaciones/idioma (solo UI local) | `home_screen.dart` (drawer) | — | Ninguno | No |
| `conductor_en_la_zona_screen.dart` | Aviso de que el conductor llegó al origen | `rastreo_screen.dart` | — (callbacks `onChat`/`onCall` del padre) | Ninguno directo | No |
| `detalle_resolucion_screen.dart` | Detalle de la resolución de una disputa | `resolucion_screen.dart` | — | Ninguno (recibe parámetros; **ver §7**, siempre muestra datos de ejemplo) | No |
| `disputa_creada_screen.dart` | Confirma que el reporte/disputa fue recibido | `reportar_problema_screen.dart` | `disputa_en_revision_screen.dart` | Ninguno | No |
| `disputa_en_revision_screen.dart` | Estado "en revisión" de una disputa | `disputa_creada_screen.dart` | `resolucion_screen.dart` | `ApiClient.getDispute(id)` (`GET /api/disputes/:id`) | No |
| `oferta_aceptada_screen.dart` | Celebración al aceptar una oferta | `ofertas_recibidas_screen.dart`, `rastreo_screen.dart` (reemplaza ruta) | — | Ninguno | No |
| `resolucion_screen.dart` | Resultado/reembolso de una disputa resuelta | `disputa_en_revision_screen.dart` | `detalle_resolucion_screen.dart` | Ninguno (datos recibidos por parámetros) | No |
| `viaje_finalizado.dart` | Resumen del viaje: costo, comisión, total | `rastreo_screen.dart` | `calificar_conductor_screen.dart` | Ninguno directo | No |
| `chat_screen.dart` | Chat en vivo cliente–conductor durante el viaje | `rastreo_screen.dart` | — | `ApiClient.getTripMessages`/`sendTripMessage`; socket `chat:message`, `typing:start/stop`, `message:read`, emite `message:send` (**ver §7**), `typing:start/stop`, `message:read` | No |
| `chat_thread_screen.dart` | Widget genérico de hilo de chat (reusado) | `soporte_screen.dart`, `emergencia_chat_screen.dart` | — | Callbacks inyectados (fetch/enviar) + stream de socket inyectado | No |
| `emergencia_chat_screen.dart` | Chat de la alerta SOS con soporte | `rastreo_screen.dart` (botón SOS) | — (envuelve `chat_thread_screen.dart`) | `SosService.getChatMessages/sendChatMessage`; socket `emergency:message` | No |
| `soporte_screen.dart` | Lista de conversaciones de soporte | `home_screen.dart`, `rastreo_screen.dart` | pantalla de chat de soporte (envuelve `chat_thread_screen.dart`) | `ChatService` conversaciones; socket `conversation:message` | No |
| `confirmar_entrega_screen.dart` | Confirmar o rechazar la entrega | `rastreo_screen.dart` | — (callbacks `onConfirmar`/`onRechazar` del padre) | Ninguno directo (el padre llama `confirm-close`) | Sí (`confirmar_entrega_test.dart`) |
| `calificar_conductor_screen.dart` | Calificar al conductor tras el viaje | `viaje_finalizado.dart` | — (`onSubmitted` hace `popUntil(isFirst)`) | `ApiClient.rateTrip` (`POST /api/trips/:id/rate`) | No |
| `llegada_al_destino_screen.dart` | Llegada al destino + evidencia | `rastreo_screen.dart` | `confirmar_entrega_screen.dart` (vía `onVerDetalle` del padre) | Ninguno directo | No |
| `ofertas_recibidas_screen.dart` | Lista de ofertas de conductores | `rastreo_screen.dart` | `oferta_aceptada_screen.dart` | `OfferService.getOffers` (GET al abrir); socket `new:offer`, `trip:offer_received`, `offer:cancelled`; callbacks `onAccept/onReject` → `acceptOffer/rejectOffer` | Sí (`ofertas_recibidas_test.dart`) |
| `pagos_screen.dart` | Estado de cuenta y comprobante de pago | `home_screen.dart` (drawer) | — | `PaymentService.getDebtInfo/uploadProof` | No |
| `perfil_screen.dart` | Ver/editar perfil y avatar, logout | `home_screen.dart` | `auth_screen.dart` (logout) | `ApiClient.getProfile/uploadAvatar/updateProfile/logout` | No |
| `reportar_problema_screen.dart` | Reportar problema → crea disputa | `rastreo_screen.dart` | `disputa_creada_screen.dart` | `TripService.disputePhoto` (evidencia), `ApiClient.createDispute` | No |
| `mis_envios_screen.dart` | Historial de envíos | `home_screen.dart` | `viaje_detalle_screen.dart` | `ApiClient.getTripHistory` | No |
| `viaje_detalle_screen.dart` | Detalle de un viaje del historial | `mis_envios_screen.dart`, `home_screen.dart` | — | `ApiClient.getTripDetail`, `rateTrip` | No |
| `nuevo_envio_screen.dart` | Crear una nueva solicitud de envío | `home_screen.dart` | `rastreo_screen.dart` | `ApiClient.requestTrip` (`POST /api/trips/request`); geocodificación directa a Nominatim (no pasa por el backend) | Sí (`nuevo_envio_screen_test.dart`) |
| `home_screen.dart` | Inicio del cliente: header, drawer, viaje activo, recientes | `home_by_role.dart` (tras login/registro/recuperar sesión) | `ajustes_screen.dart`, `mis_envios_screen.dart`, `nuevo_envio_screen.dart`, `pagos_screen.dart`, `perfil_screen.dart`, `rastreo_screen.dart`, `soporte_screen.dart`, `viaje_detalle_screen.dart`, `notifications_screen.dart`, `auth_screen.dart` | `ApiClient.getActiveTrip/getTripHistory/logout`; `NotificationService.onNotification` (redirige a `rastreo_screen` en `new:offer`/`trip:status_changed`/`trip:cancelled`) | No |
| `cliente_inicio_view.dart` | Contenido visual del inicio (embebido en `home_screen.dart`) | `home_screen.dart` | — | Ninguno (solo callbacks del padre) | Sí (`cliente_inicio_view_test.dart`) |
| `cancel_trip_screen.dart` | Formulario de motivo para cancelar | `rastreo_screen.dart` | — (devuelve resultado con `Navigator.pop`) | Ninguno directo | Sí (`cancel_trip_motivo_test.dart`) |
| `rastreo_screen.dart` | Pantalla central de seguimiento en todos los estados del viaje | `home_screen.dart`, `nuevo_envio_screen.dart` | `busqueda_conductor_view.dart` (embebido), `cancel_trip_screen.dart`, `ofertas_recibidas_screen.dart`, `oferta_aceptada_screen.dart`, `confirmar_entrega_screen.dart`, `viaje_finalizado.dart`, `reportar_problema_screen.dart`, `conductor_en_la_zona_screen.dart`, `llegada_al_destino_screen.dart`, `chat_screen.dart`, `emergencia_chat_screen.dart`, `soporte_screen.dart` | Ver §6 (tabla de sockets) y §4 | Sí (`rastreo_estado_test.dart`) |
| `busqueda_conductor_view.dart` | Vista "buscando conductor" (mapa, ofertas, resumen) | `rastreo_screen.dart` (embebido) | — | UI pura, callbacks del padre; define el sheet `elegirMotivoCancelacionBusqueda` | Sí (`busqueda_conductor_view_test.dart`) |
| `user/auth_screen.dart` | Bienvenida con botones login/registro | `main.dart`, `home_by_role.dart`, logout de varias pantallas | `login_screen.dart`, `register_screen.dart` | Ninguno | No |
| `user/login_screen.dart` | Formulario de inicio de sesión | `auth_screen.dart`, `register_screen.dart` | Home según rol (vía `home_by_role.dart`) | `ApiClient.login` (`POST /api/auth/login`) | No |
| `user/register_screen.dart` | Formulario de registro (cliente/conductor) | `auth_screen.dart` | Home según rol o `login_screen.dart` | `ApiClient.register` (`POST /api/auth/register`) | No |
| `conductor/notifications_screen.dart` (compartida) | Lista de notificaciones | `home_screen.dart` (cliente), `conductor/home_screen.dart` | — | `NotificationService` (listar, refrescar, marcar leída/todas) | No |

Cobertura de test: 7 de ~28 pantallas de cliente tienen test dedicado (`test/screens/cliente/*.dart`).

---

## 4. Ciclo del viaje

Estados (`lib/contracts/trip_status.dart`) → vista de `RastreoScreen` (`rastreoVistaPara()` en `lib/screens/cliente/rastreo_screen.dart`):

| Estado(s) backend | `RastreoVista` | Contenido |
|---|---|---|
| `creado`, `buscando_conductor`, `pendiente` | `busqueda` | `BusquedaConductorView` |
| `aceptado`, `conductor_en_camino`, `conductor_llegada`, `en_curso`, `sos` | `seguimiento` | Mapa + tracking |
| `entregado`, `esperando_confirmacion`, `pendiente_confirmacion`, `finalizado` | `entrega` | Confirmación de entrega / finalizado |
| `disputa`, `en_disputa` | `disputa` | Panel informativo (soporte / volver a inicio) |
| `cancelado`, `rechazado` | `cerrado` | Panel informativo |
| `reservado` | `reserva` | "Reserva programada" |
| (desconocido) | `seguimiento` (fallback) | — |

### Flujo feliz

1. **Nuevo envío** (`nuevo_envio_screen.dart`): el cliente fija `precioCliente` (no hay cotización del backend) → `POST /api/trips/request` → abre `rastreo_screen.dart`.
2. **Buscando conductor** — `BusquedaConductorView`; polling de respaldo cada 5 s (más lento si el socket está conectado) vía `GET /api/trips/active`, y polling de conductores cercanos cada 10 s (`GET /api/trips/:id/nearby-drivers`).
3. **Ofertas** — llegan por socket `new:offer` / `trip:offer_received`; badge "Ver ofertas" en el AppBar de `rastreo_screen.dart` abre `OfertasRecibidasScreen` (esta pantalla sí hace `GET /api/trips/:id/offers` al abrir).
4. **offer:accepted** (socket) → `rastreo_screen.dart` reemplaza la ruta por `OfertaAceptadaScreen`.
5. **Seguimiento** — estados `aceptado`/`conductor_en_camino`/`conductor_llegada`/`en_curso`; posición del conductor vía socket `driver:location`; si el socket está caído, `_startFallbackPolling` (10 s) sincroniza con `GET /api/trips/active`.
6. **en_curso** → viaje en curso hacia destino.
7. **Solicitud de cierre**: el conductor dispara `trip:finalize_request` (socket) → `rastreo_screen.dart` abre `LlegadaAlDestinoScreen` → `ConfirmarEntregaScreen`:
   - **Confirmar** → `POST /api/trips/:id/confirm-close` (`confirmar: true`) → `ViajeFinalizado` (`pushAndRemoveUntil`, deja solo la raíz + esta pantalla).
   - **Rechazar** → `POST /api/trips/:id/confirm-close` (`confirmar: false`, motivo) → `ReportarProblemaScreen` (crea disputa). Ver bug de motivo ignorado en §7.
8. **ViajeFinalizado** → `CalificarConductorScreen` → `POST /api/trips/:id/rate` → `popUntil(isFirst)` (doble, ver §7).

### Cancelación

- **Mientras se busca conductor** (`creado`/`buscando_conductor`/`pendiente`): hoja `elegirMotivoCancelacionBusqueda` (definida en `busqueda_conductor_view.dart`) → `_doCancel(motivo)`.
- **En `en_curso` o `conductor_llegada`**: pantalla completa `CancelTripScreen(enCurso: status == en_curso)` → `_doCancel(motivo)`.
- `_doCancel` (`rastreo_screen.dart`): si `_status` es `en_curso` **o** `conductor_llegada` → `TripService.requestCancellation` (el backend bloquea la cancelación directa con 403 en esos estados: revisión por un admin). En cualquier otro estado → `TripService.cancelTrip` (cancelación directa). Antifraude: 403 `CONDUCTOR_CERCA` si el conductor está a <1 km del origen; 403 `JUSTIFICACION_REQUERIDA` en algunos casos.
- Bug de motivos por estado: ver §7 (los motivos de "en curso" no se muestran para `conductor_llegada` aunque usa la misma llamada `requestCancellation`).

### Disputa

`reportar_problema_screen.dart` (`ApiClient.createDispute`, `POST /api/disputes`) → `DisputaCreadaScreen` → `DisputaEnRevisionScreen` (`GET /api/disputes/:id`) → si está resuelta, `ResolucionScreen` (con `resultado`/`reembolso` reales de la disputa) → `DetalleResolucionScreen` (bug: siempre muestra datos de ejemplo, ver §7).

---

## 5. Endpoints REST usados por el cliente

Todas las rutas fueron contrastadas contra `bakend-cargaexpress/start/routes.ts`; no se encontraron endpoints huérfanos (sin ruta backend).

| Método | Ruta | Servicio Flutter | Body/params principales | Notas |
|---|---|---|---|---|
| POST | `/api/auth/login` | `auth_service.dart` | `{email, password}` | Rate-limit 10/min |
| POST | `/api/auth/register` | `auth_service.dart` | datos de registro | |
| POST | `/api/auth/refresh-token` | `auth_service.dart` | `{refreshToken}` | Usado internamente por `HttpClient.refreshSessionShared` |
| POST | `/api/auth/logout` | `auth_service.dart` | `{refreshToken?}` | Nunca lanza (logout local no depende de red) |
| GET/PUT | `/api/users/profile` | `profile_service.dart` | perfil | |
| POST | `/api/users/avatar` | `profile_service.dart` | multipart `file` | |
| PUT | `/api/users/fcm-token` | `notification_service.dart` | `{fcmToken}` | |
| POST | `/api/trips/request` | `trip_service.dart` | body del envío | `idempotent:true`, rate-limit 5/min |
| GET | `/api/trips/active` | `trip_service.dart` | — | 404 → `null`. **Excluye `pendiente_confirmacion`** (ver §7) |
| GET | `/api/trips/history` | `trip_service.dart` | `page, limit, estado?` | |
| GET | `/api/trips/:id` | `trip_service.dart` | — | |
| GET | `/api/trips/:id/nearby-drivers` | `trip_service.dart` | — | |
| GET | `/api/trips/nearby` | `trip_service.dart` | `lat, lng, radio` | (uso conductor) |
| POST | `/api/trips/:id/offers` | `offer_service.dart` | `{monto, placa?, mensaje?}` | Rate-limit 10/min (conductor) |
| GET | `/api/trips/:id/offers` | `offer_service.dart` | — | |
| POST | `/api/trips/:id/offers/:offerId/accept` | `offer_service.dart` | — | |
| POST | `/api/trips/:id/offers/:offerId/reject` | `offer_service.dart` | — | |
| POST | `/api/trips/:id/cancel` | `trip_service.dart` | `{motivo?, justificacion?}` | Cancelación directa |
| POST | `/api/trips/:id/request-cancellation` | `trip_service.dart` | `{motivo?, justificacion?}` | Revisión de admin (en_curso/conductor_llegada) |
| POST | `/api/trips/:id/confirm-close` | `trip_service.dart` | `{confirmar, motivo?}` | `idempotent` opcional |
| POST | `/api/trips/:id/dispute` | `trip_service.dart` | `{motivo, descripcion?}` | |
| POST | `/api/trips/:id/dispute/appeal` | `trip_service.dart` | `{motivo, descripcion?}` | |
| POST | `/api/trips/:id/dispute/support` | `trip_service.dart` | multipart `file` (hasta 10 MB) | evidencia de disputa |
| POST | `/api/trips/:id/rate` | `trip_service.dart` | `{puntaje, comentario?}` | |
| POST | `/api/trips/:id/delivery-photo` | `trip_service.dart` | multipart `file` | (uso conductor) |
| GET/POST | `/api/trips/:id/chat` | `chat_service.dart` | `{mensaje}` | |
| GET/POST | `/api/conversations`, `/api/conversations/:id/messages` | `chat_service.dart` | `{mensaje}` | soporte |
| GET | `/api/conversations/unread-count` | `chat_service.dart` | — | tolera error → 0 |
| POST | `/api/disputes` | `dispute_service.dart` | `{tripId, problema, descripcion?, fotos?[]}` | |
| GET | `/api/disputes/:id` | `dispute_service.dart` | — | |
| POST | `/api/disputes/:id/version` | `dispute_service.dart` | `{version}` | |
| GET/POST/DELETE | `/api/favorites` | `favorite_service.dart` | rutas favoritas | |
| GET | `/api/notifications` | `profile_service.dart` | `page, limit` | |
| PUT | `/api/notifications/:id/read` | `profile_service.dart` | — | |
| GET | `/api/settings`, PUT `/api/settings` | `profile_service.dart` | ajustes | |
| GET | `/api/support/help` | `profile_service.dart` | — | |
| GET | `/api/support/emergency` | `profile_service.dart` | — | números de emergencia (distinto de alertas SOS) |
| GET | `/api/config/coverage` | `coverage_service.dart` | — | público, sin `auth` |
| GET | `/api/config/mapbox` | `profile_service.dart` | — | `auth: true` |
| POST | `/api/emergency` | `sos_service.dart` | `{viajeId?, motivo?, lat, lng}` | Ver §7: `lat/lng = 0,0` si no hay GPS |
| GET/POST | `/api/emergency/:id/messages` | `sos_service.dart` | `{mensaje}` | chat de la alerta SOS |
| GET | `https://nominatim.openstreetmap.org/reverse` y `/search` | directo desde `nuevo_envio_screen.dart` (no pasa por el backend) | `lat/lon` o `q` | `User-Agent` propio, `Accept-Language: es`, límite 1 req/s, timeout 10 s |

Endpoints de conductor/driver, moderador y admin (earnings, verification, moderator/*, admin/*) existen pero quedan fuera del alcance de este documento (lado cliente).

---

## 6. Tiempo real

### Conexión — `lib/services/socket_service_client.dart`

`io.io(Environment.baseUrl, {transports:['websocket'], auth:{token}, query:{token}, forceNew:true, reconnection:false})`. Reconexión manual con backoff exponencial (1 s × 2^intento, tope 30 s, máx. 50 intentos); `reconnection:false` porque el backoff lo maneja el cliente. `forceReconnect()` se llama tras login/registro (`ApiClient._saveTokens`) y al volver a foreground (`AppLifecycleService`). `disconnect()` se llama en `ApiClient.clearTokens`/logout.

### Eventos relevantes para el cliente

| Evento | Dirección | Quién lo usa | Para qué |
|---|---|---|---|
| `trip:status_changed` | escucha | `rastreo_screen.dart`, `notification_service.dart` | Estado del viaje cambia |
| `driver:location` | escucha | `rastreo_screen.dart` | Posición en vivo del conductor |
| `new:offer` | escucha | `rastreo_screen.dart`, `ofertas_recibidas_screen.dart`, `home_screen.dart` | Nueva oferta durante la búsqueda |
| `trip:offer_received` | escucha | `ofertas_recibidas_screen.dart` | Expiración/actualización de ofertas |
| `offer:accepted` | escucha | `rastreo_screen.dart` → abre `OfertaAceptadaScreen` | Cliente aceptó una oferta |
| `offer:cancelled` | escucha | `ofertas_recibidas_screen.dart` | El conductor reemplazó su oferta |
| `trip:accepted` | escucha | `rastreo_screen.dart`, `notification_service.dart` (aviso "Conductor asignado") | **Solo lo emite la ruta deprecada** `TripController.accept` (ver §7) |
| `trip:started` | escucha | `rastreo_screen.dart` | Viaje iniciado (`en_curso`) |
| `trip:finalize_request` | escucha | `rastreo_screen.dart` → abre `LlegadaAlDestinoScreen` | Conductor pide cerrar el viaje |
| `trip:finalize_cancelled` | escucha | `rastreo_screen.dart` | Conductor canceló la solicitud de cierre |
| `trip:cancelled` | escucha | `rastreo_screen.dart`, `notification_service.dart`, `notification_provider.dart` | Viaje cancelado |
| `trip:delivered` | escucha | listener registrado, **sin consumidor real** (comentario en `rastreo_screen.dart:216`) | El backend nunca lo emite (ver §7) |
| `chat:message` | escucha | `chat_screen.dart` | Mensaje de chat del viaje |
| `typing:start`/`typing:stop`, `message:read` | escucha/emite | `chat_screen.dart` | Indicador "escribiendo…", doble check |
| `conversation:message` | escucha | `soporte_screen.dart` | Chat de soporte |
| `emergency:message` | escucha | `emergencia_chat_screen.dart` | Chat de la alerta SOS |
| `notification:new`, `notification:read`, `notification:delete` | escucha | `notification_service.dart`, `notification_provider.dart` | Notificaciones guardadas en backend |
| `sos:activated` | escucha | expuesto (`onSosActivated`) | Alerta SOS |
| `join:trip` / `leave:trip` | emite | `rastreo_screen.dart` (`initState`/reconexión y `dispose`) | Unirse/salir de la sala del viaje |
| `trip:finalize_response` | emite | `rastreo_screen.dart` (tras confirmar/rechazar entrega) | Aviso al conductor "por compatibilidad" |
| `message:send` | emite | `chat_screen.dart._sendMessage()` | Ver §7: además del POST |

Eventos emitidos por el backend que la app **no** escucha: `trip:reserved`, `trip:search_started`, `trip:declined` (ver §7). Eventos de conductor/admin/moderador (`driver:on_the_way`, `driver:stop_gps`, `admin:*`, `moderator:*`, `dispute:updated/resolved`, etc.) existen en `socket_service_client.dart` pero no los consume ninguna pantalla de cliente.

### Polling de respaldo — `rastreo_screen.dart`

- `_startPolling()`: cada 5 s (cada ~15 s si el socket está conectado) mientras `_status == buscando_conductor`; `GET /api/trips/active`.
- `_startCercanosPolling()`: cada 10 s mientras se busca conductor; `GET /api/trips/:id/nearby-drivers`.
- `_startFallbackPolling()`: cada 10 s, siempre activo pero solo actúa si el socket está desconectado; `GET /api/trips/active`.
- `chat_screen.dart` también hace polling de mensajes (5 s) cuando detecta el socket desconectado.

### FCM — `lib/services/notification_service.dart`

- Token registrado con `PUT /api/users/fcm-token`; se re-registra en `onTokenRefresh`.
- Primer plano: `FirebaseMessaging.onMessage` agrega la notificación a la lista unificada.
- Background/terminada: `onMessageOpenedApp` / `getInitialMessage()` marcan `__tap` y, si es `new_trip`/`trip:nearby`, `__navigate: 'offers'` para que la UI navegue.
- Es independiente de `NotificationProvider` (`lib/providers/notification_provider.dart`): ambos se suscriben por separado a los streams de `SocketServiceClient`, no se llaman entre sí.

---

## 7. Desajustes conocidos (pendientes)

- [ ] `GET /api/trips/active` excluye `pendiente_confirmacion` (`bakend-cargaexpress/app/controllers/trip_controller.ts:505`, `.whereIn('estado', [...])` sin ese estado). Tras reiniciar la app no se puede volver a confirmar la entrega y se puede solicitar un 2º viaje.
- [ ] La app escucha `trip:delivered` (`lib/services/socket_service_client.dart:329`) pero el backend nunca lo emite (confirmado por grep en `bakend-cargaexpress/app`); el propio código lo documenta en `rastreo_screen.dart:216`.
- [ ] El aviso "Conductor asignado" depende de `trip:accepted`, que solo emite la ruta deprecada `TripController.accept` (`trip_controller.ts:518-520,653`, marcada `OBSOLETO`/`Deprecation`). El flujo actual de ofertas emite `offer:accepted` (`offer_controller.ts:372`), no `trip:accepted`, así que ese aviso normalmente no se dispara.
- [ ] Los motivos de cancelación de "en curso" no se muestran en `conductor_llegada`: `rastreo_screen.dart:512` trata ambos estados igual para llamar `requestCancellation`, pero `rastreo_screen.dart:553` solo activa `CancelTripScreen(enCurso: true)` cuando el estado es exactamente `en_curso`; `conductor_llegada` recibe la lista genérica de motivos en `cancel_trip_screen.dart:43`.
- [ ] Eventos que emite el backend y la app no escucha: `trip:reserved` (`trip_controller.ts:306`), `trip:search_started` (`reservation_activation_service.ts:126`), `trip:declined` (`trip_controller.ts:830`).
- [ ] SOS sin GPS envía `lat/lng = 0,0` como fallback (`lib/services/sos_service.dart:13-22`) en vez de omitir el campo o bloquear el envío.
- [ ] `ConfirmarEntregaScreen`: el campo de motivo de rechazo no tiene `controller` (`lib/screens/cliente/confirmar_entrega_screen.dart:45-52`) — el texto escrito se descarta y siempre se envía el literal `'Cliente rechazó la entrega'` (línea 61). Además, si `confirm-close` falla, el padre (`rastreo_screen.dart:592-611,637-653`) solo muestra un SnackBar sin resetear el `_loading` del hijo: los botones quedan deshabilitados permanentemente tras un error.
- [ ] Ofertas al reabrir Rastreo: `OfertasRecibidasScreen` sí hace `GET /api/trips/:id/offers` al abrir, pero el badge "Ver ofertas" de `rastreo_screen.dart` (`_hasOffers`/`_ofertas`) solo se alimenta del socket `new:offer` (`rastreo_screen.dart:249-257`) y nunca de un GET al reabrir la pantalla — si las ofertas llegaron antes de reabrir/reiniciar, el botón no aparece.
- [ ] Posible doble apertura de Rastreo desde Home: `home_screen.dart:72-79` abre `RastreoScreen` en `new:offer` si la ruta es `isFirst`, sin comprobar `_redirected`; `_loadActiveTrip()`/`_redirectToTracking()` (líneas 99-116, 153-162) programan otra apertura vía `addPostFrameCallback` guardada solo por `_redirected`. Si un `new:offer` llega en esa ventana, ambos caminos pueden empujar `RastreoScreen` por separado.
- [ ] `CalificarConductorScreen`: se puede enviar una calificación con 0 estrellas (el botón solo se deshabilita por `_submitting`, no valida `_rating > 0`, `calificar_conductor_screen.dart:168-190`). Además hay doble `popUntil(isFirst)`: una vez dentro de la pantalla (línea 181) y otra en el callback `onSubmitted` del padre (`viaje_finalizado.dart:27-29`).
- [ ] `NotificationProvider`/`SessionMonitorService` no arrancan tras login o registro: solo se inician en frío en `main.dart:66,259` (o en el panel admin); no hay llamada en `login_screen.dart`, `register_screen.dart` ni `home_by_role.dart`.
- [ ] El chat emite `message:send` por socket además del POST (`chat_screen.dart:212-218`). El backend escucha el evento (`socket.ts:316-326`) pero solo valida participación, no persiste ni reemite — no duplica el mensaje en BD, pero es código redundante/muerto.
- [ ] Datos de demo fijos en `detalle_resolucion_screen.dart:12-25` (número de disputa, problema, resultado, reembolso, comentario y fecha de ejemplo): `resolucion_screen.dart:122-127` la abre sin pasar esos valores, así que en producción siempre muestra el ejemplo, nunca los datos reales de la disputa. (`reportar_problema_screen.dart` y `disputa_en_revision_screen.dart` sí usan datos reales de la API — no tienen este problema.)
- [ ] ETA fijo `'5 min'` hardcodeado en `rastreo_screen.dart:1100`.
- [ ] Comisión del 10% mostrada al cliente y restada de "Total pagado" en `viaje_finalizado.dart:44-45,111` — la comisión normalmente es un descuento del lado del conductor, no del cliente.
