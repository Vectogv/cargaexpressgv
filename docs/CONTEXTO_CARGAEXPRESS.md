# CargaExpress: mapa funcional para Claude

> Para futuras sesiones de Claude. Describe **qué hace** el sistema y **dónde está** cada cosa (app, servidor y web).
> El estado del trabajo (qué falta, qué se probó, cuentas de prueba) NO va aquí: está en `CLAUDE.local.md` (local, sin git).
> Actualizado: 2026-10-07. Si algo de aquí choca con el código, manda el código; y si la app y el servidor no coinciden, manda el servidor.

## 1. Qué es

App de fletes en Popayán (Colombia):

1. El cliente publica un envío con su precio.
2. Los conductores cercanos ofertan, y el cliente acepta una oferta.
3. Hay seguimiento en vivo hasta la entrega, que se cierra con PIN.

La empresa cobra **10 % de comisión** al conductor, que se acumula como deuda y se paga por Nequi con comprobante.

| Parte | Carpeta | Tecnología | Publicación |
|---|---|---|---|
| App (cliente y conductor) | `C:\Users\automatacionsena\cargaexpressgv` | Flutter, 2 flavors | Google Play (prueba cerrada) y APK |
| Servidor | `C:\Users\automatacionsena\bakend-cargaexpress` | AdonisJS 6, PostgreSQL, Redis, Socket.IO | Railway: `https://bakend-cargaexpress-production.up.railway.app` |
| Panel web | `C:\Users\automatacionsena\pagina_express` | React 19, Vite, react-router 7, axios, leaflet | Vercel `https://paginaexpress.vercel.app` (push a `main`) |

Roles: `cliente`, `conductor` y `admin` son el campo `rol`. **Moderador** (`esModerador` + `zonaModerador`) y **líder** (`esLider`, un conductor con permisos de grupo) son banderas.

---

## 2. Servidor (`bakend-cargaexpress`)

### Arquitectura
- `app/controllers/`: auth, profile, driver, trip, offer, chat, conversacion, dispute, emergency, emergency_chat, favorite_route, fraud_alert, gerencia, leader, mapbox, moderator, admin, notification, payment, report, settings, support, ticket.
- `app/services/`: la lógica de negocio. Los principales:
  - `trip_state_machine.ts`, `trip_finalization_service.ts`, `trip_dispatch_service.ts`, `trip_route_service.ts` (Mapbox);
  - `busqueda_escalera_service.ts`, `busqueda_timeout_service.ts`, `reservation_activation_service.ts`, `confirmacion_timeout_service.ts`, `offer_expiry_service.ts`;
  - `driver_debt_suspension_service.ts`, `antifraude_service.ts`, `filtro_contacto.ts`, `calificacion_conductor.ts`, `archivado_cuenta_service.ts`;
  - `push_notification_service.ts`, `mail_service.ts` (Brevo), `backup_service.ts`, `coverage_service.ts` (`claveDe`), `geo_service.ts`.
- Otras carpetas:
  - `app/models/` (Lucid: `viaje`, `oferta`, `conductor`, `user`, `disputa`, `ticket_soporte`, `configuracion_plataforma`…);
  - `app/validators/` (VineJS);
  - `app/middleware/` (`auth`, `admin`, `moderator`, `leader`, `leader_permission`, `rate_limit`, `idempotency`);
  - `app/transformers/`;
  - `contracts/` (`trip_status.ts`, `socket_events.ts`);
  - `config/antifraude.ts`, `config/reservations.ts`.
- `start/routes.ts` tiene todas las rutas y `start/socket.ts`, las salas y los emisores.
- `database/migrations/`: ~80 migraciones. **`start.sh` corre `migration:run --force` al arrancar**, así que desplegar ya migra.
- `/health` devuelve 200 `ok`, o `degradado` si Redis está en memoria (es normal), y 503 si falla la base de datos.
- `/docs` y `/swagger` sirven el OpenAPI.

### Programador interno (`providers/reservation_scheduler_provider.ts`)
- Corre un tick cada 60 s con un lock en Redis y no corre en las pruebas. En cada tick, en orden:
  1. activa las reservas, manda recordatorios y vence los plazos;
  2. avisa al moderador de los cierres sin confirmar;
  3. suspende a los conductores con deuda vencida;
  4. avanza la escalera de búsqueda;
  5. cancela las búsquedas vencidas;
  6. archiva las cuentas inactivas (cada 6 h).
- Hay otro tick cada 30 s que vence las ofertas.
- El respaldo diario está en `providers/backup_scheduler_provider.ts`: a las 3:00 a. m. de Colombia hace `pg_dump`, lo comprime con gzip, lo sube a Google Drive y guarda 30.

### Tiempo real y avisos
- **Socket.IO.** Salas: `user:{id}`, `client:{id}`, `driver:{id}`, `admin`, `leader`, `moderator:{claveDe(zona)}` y `trip:{id}`. Eventos clave:
  - viaje: `trip:status_changed` (lleva `busqueda`), `trip:accepted`, `trip:cancelled`, `trip:plazo`;
  - ruta y GPS: `trip:eta_update`, `trip:route_update`, `driver:location`;
  - ofertas: `offer:accepted`, `offer:rejected`, `offer:expired`;
  - cuenta y avisos: `notification:new`, `account:payment_suspended`, `payment:confirmed`;
  - moderador: `moderator:pending_close`, `moderator:trip:update`.
- **Push FCM.** Va con `data {tipo, viajeId}` y prioridad alta. Los tipos son `viaje_estado`, `viaje_cancelado`, `reserva`, `reserva_plazo`, `ticket_mensaje`, `ticket_estado`, `conversacion_mensaje` y `disputa_resuelta`.
  - Los de viaje también dejan una fila en la bandeja (`notificaciones`).
  - El canal Android de los viajes es `cargaexpress_viajes`.
- **Correo.** Va por Brevo y solo se usa para el código de recuperación de contraseña (6 dígitos, vence en 10 min).

### Rutas (resumen; el detalle está en `start/routes.ts`)
- **Auth** (`/api/auth`, 10 por minuto):
  - `register` acepta correo o `idToken` de Google;
  - `login`, `refresh-token`, `logout`;
  - `forgot-password` y `reset-password`;
  - `google`: si la cuenta no existe responde 404 `CUENTA_NO_EXISTE` y no la crea.
- **Usuario** (`/api/users`): `profile` (GET y PUT; el email no se puede cambiar), `password`, `DELETE me` (archiva la cuenta, o da 409 si hay viaje, deuda o disputa), `avatar` y `fcm-token`. Además `/api/settings` y `/api/favorites`.
- **Viajes** (`/api/trips`):
  - Crear y consultar:
    - `request` y `reserve` (idempotentes);
    - `nearby`, `active`, `reservations`, `history` y `:id`.
  - Ofertas:
    - `:id/offers` (GET y POST);
    - `:id/offers/:offerId/accept` y `…/reject`.
  - Recogida, en ese orden: `:id/confirm-arrival`, `:id/confirm-pickup` y `:id/start-trip`.
  - Cierre:
    - `:id/complete` (con PIN) o su alias `:id/finalize`, y después `:id/confirm-close`;
    - `:id/cancel` y `:id/request-cancellation`.
  - Escalera:
    - `PUT :id/precio {precio}`: tiene que ser mayor que el actual y como máximo 3 veces el actual;
    - `POST :id/seguir-esperando`: solo en la etapa `cierre`.
  - Reservas: `:id/plazo` (lo pide el conductor) y `:id/plazo/responder` (responde el cliente).
  - Otras:
    - `:id/rate`, `:id/report`, `:id/delivery-photo`, `:id/pickup-photo`;
    - `:id/route`: ruta y ETA más `conductor{lat,lng}`;
    - `:id/chat`, `:id/dispute`.
- **Conductor** (`/api/drivers`):
  - estado y ubicación: `status`, `location`;
  - ganancias y estadísticas: `earnings`, `earnings/history`, `earnings/pdf`, `stats`, `today-stats`, `offers`;
  - grupo: `grupo` y los comentarios de los avisos;
  - documentos: `verification/:tipo`, `verification-soat/excepcion` y las fotos.
- **Otros endpoints:**
  - `/api/notifications` (incluye `read-all`) y `/api/conversations` (chat con moderadores);
  - `/api/support/tickets…`, `/api/emergency` (SOS) y `/api/payment` (`debt` y `proof`);
  - `/api/config/banner`, `coverage` y `cliente`.
- **Admin** (`/api/admin`):
  - personas y documentos: usuarios, conductores, verificaciones;
  - operación: viajes, disputas, emergencias, reportes, tickets, cancelaciones;
  - dinero: comisiones, pagos (`confirm`, `reject`) y `clear-debt`;
  - roles: moderador, líder, rol;
  - configuración: `config` (Nequi, zonas, banner, **`escalera`**) y respaldos;
  - comunicación: `pendientes`, `comunicacion`, comunicados y encuestas.
- **Moderador y líder:**
  - `/api/moderator`: lo de su zona, `trips/:id/resolve-close {resolucion:'finalizar'|'disputa'}`, emergencias, conversaciones y tickets.
  - `/api/leader`: avisos y comunicados, con permisos por ruta.

### Estados del viaje (`contracts/trip_status.ts`, `trip_state_machine.ts`)
`reservado` → `buscando_conductor`/`pendiente` → `aceptado` → `conductor_en_camino` → `conductor_llegada` → `en_curso` → `pendiente_confirmacion` → `finalizado`. Además:
- el cliente puede rechazar el cierre → `disputa`, que solo resuelve el admin;
- puede pasar a `cancelado` hasta `en_curso`;
- `sos` puede ocurrir desde `aceptado`.

### Reglas de negocio (las aplica el servidor)
- **Radios antifraude** (`config/antifraude.ts`):
  - recoger e iniciar solo a menos de 1 km del origen;
  - cerrar cerca del destino. Lejos del destino exige una justificación de 10 caracteres o más y queda marcado como posible fraude;
  - el cliente no puede cancelar con el conductor a menos de 1 km;
  - la ubicación del conductor debe tener menos de 180 s;
  - solo se oferta a menos de 20 km del origen.
- **Ofertas:** vencen a los ~28 s; en las reservas no vencen. Al aceptar, `precioFinal = monto de la oferta` y se genera `pinEntrega`, que el conductor nunca ve.
- **Cierre con PIN:** el conductor manda el PIN de 4 dígitos que le dicta el cliente (si falta o está mal, responde 422 `PIN_REQUERIDO` o `PIN_INCORRECTO`). Pasa a `pendiente_confirmacion`, y el cliente confirma o rechaza. Si no responde en 10 min, se avisa al moderador de la zona.
- **Escalera de búsqueda** (sin estado nuevo; el viaje lleva el objeto `busqueda`):
  - Forma: `busqueda {etapa:'publicado'|'ampliada'|'sugerencia'|'cierre', mensaje, precioSugerido:{min,max}|null, cierreHasta}`.
  - Valores por defecto, editables en la web (Configuración → Búsqueda):
    1. al publicar se avisa en 3 km;
    2. a los 3 min se amplía a 8 km, sumando a los conductores que están terminando un viaje;
    3. a los 5 min se sugiere un precio: percentiles 25 a 75 de viajes finalizados parecidos o, con menos de 5 viajes, +15/+30 %;
    4. a los 20 min se pregunta al cliente, que tiene 10 min para responder; "Seguir esperando" da 20 min más.
  - Con una oferta viva no se sube de etapa. Las reservas activadas no entran en la escalera y siguen la regla vieja de 15 min.
- **Reservas:**
  - se piden con 120 min o más de anticipación;
  - se pueden ofertar desde que se crean, y aceptar las deja `reservado` con el conductor asignado;
  - pasan a `aceptado` 45 min antes;
  - el conductor puede pedir una vez +15/30/60 min, y el cliente tiene 5 min para responder;
  - si el conductor cancela, la reserva se reabre, con castigo solo si faltan menos de 24 h.
- **Deuda del conductor:**
  - la comisión se suma a `monto_deuda`;
  - con más de $100.000 de deuda no puede conectarse ni ofertar (`DEUDA_SUPERA_TOPE`);
  - si vence el plazo, la cuenta pasa a `suspension_por_pago`;
  - el comprobante deja la cuenta en `esperando_confirmacion` hasta que el admin lo revisa.
- **Penalización:** cancelar un viaje asignado resta 0,5 a la calificación visible del conductor (`penalizacion_cancelacion`, nunca se perdona).
- **Chat:** bloquea con 422 los teléfonos (7 o más dígitos), los correos y las palabras WhatsApp y Telegram.
- **Cuenta:**
  - edad mínima de 18 años;
  - "Eliminar cuenta" archiva (`archivada_at`) y no borra nada;
  - 6 meses sin uso también archiva;
  - el login de una cuenta archivada da 403 `CUENTA_ARCHIVADA`.
- **Zonas:** `claveDe(ciudad)` quita tildes, pasa a minúsculas y cambia lo que no es letra o número por `_`. Un moderador sin zona recibe 403.

### Pruebas
- Japa en `tests/functional` (~58 specs) y `tests/unit`. Se corren con `node ace test` (~430 pruebas) y `npx tsc --noEmit`. En las pruebas se usa SQLite.
- Flakes conocidos: `flujo_ofertas.spec.ts` ("conductor suspendido…") y `suspension_deuda_conductor.spec.ts` (placa al azar). Corridos solos, pasan.

---

## 3. App Flutter (`cargaexpressgv`)

### Arquitectura
- `lib/core/`: `environment.dart` (URL base; `--dart-define=TEST_MODE=true` apunta a `10.0.2.2:3333`), tema, `formato_dinero` y la navegación global.
- `lib/contracts/`: reglas puras que reflejan al servidor (`trip_status`, `solicitud`, `cierre`, `cancelacion`, `validacion_usuario`, `socket_events`).
- `lib/models/`: `trip.dart` (con `trip.g.dart`, json_serializable) y `user.dart`. **No commitear `user.g.dart`.**
- `lib/services/`:
  - `api_client.dart` (sesión) y `api/*.dart` (auth, trip, offer, driver, payment, profile, ticket, dispute, chat…);
  - `socket_service_client.dart`, `notification_service.dart`, `banner_service.dart`, `config_cliente_service.dart`, `background_location_service.dart`.
- `lib/screens/`: `cliente/`, `conductor/`, `user/` (entrada y registro), `shared/`, `moderador/`, `admin/`. El rol decide la pantalla en `home_by_role.dart`.
- **HTTP** (`services/api/http_client.dart`):
  - Bearer con timeout de 20 s;
  - ante un 401, una sola renovación compartida y un reintento;
  - `X-Idempotency-Key`, con una `ActionKey` por acción del usuario (`shared/action_key.dart`);
  - los errores llegan como `ApiException` con `code`.
- **Flavors:**
  - `--flavor cliente` → `co.cargaexpress.app`, solo clientes;
  - `--flavor conductor` → `co.cargaexpress.conductor`: conductor, moderador y admin.
  - El filtro está en `homeDestinoFor` y `errorDeDestino`. La app de cada flavor rechaza las cuentas del otro.
- **Push:** `MainActivity.kt` crea los canales `cargaexpress_viajes` (sonido propio `res/raw/cargaexpress_aviso.wav`) y `location_service`. Al tocar un aviso, `main.dart` abre el viaje, el ticket o la conversación.
- **Sondeos de respaldo**, porque el socket muere en segundo plano:

  | Qué | Cada cuánto |
  |---|---|
  | Ofertas | 5 s |
  | Chat y tickets | 4–5 s |
  | Posición y ruta | 8 s (`GET /trips/:id/route`) |
  | Viaje activo en el inicio | 20 s |
  | Ubicación del conductor | 10 s (15 s en segundo plano) |

### Cliente (`lib/screens/cliente/`)
- **Entrada** (`lib/screens/user/`):
  - `intro_screen.dart` (animación, una sola vez) y `auth_screen.dart` (bienvenida);
  - `login_screen.dart`, `google_login.dart` y `recuperar_password_screen.dart` (código OTP);
  - registro paso a paso en `user/registro/` (`registro_cliente.dart`, `asistente_registro.dart`, `pasos_comunes.dart`, con el borrador en SharedPreferences).
- **Inicio:** `home_screen.dart`, con barra Inicio, Mis envíos, Soporte y Perfil, más `cliente_inicio_view.dart`. Tiene 3 estados:
  - sin envío;
  - envío activo, con 4 pasos, PIN, placa y llamar;
  - confirmar entrega.

  Además muestra el tutorial (`shared/tutorial_inicio.dart`) y el anuncio en un diálogo, una vez al día.
- **Nuevo envío:**
  - pantalla `nuevo_envio_screen.dart`, con `elegir_punto_mapa_screen.dart` para escoger origen y destino;
  - ruta por las calles (Mapbox) y rutas favoritas;
  - quién recibe, precio, tipo de vehículo opcional (solo informativo) y Ahora o Programar (reserva).
- **Búsqueda:** `rastreo_screen.dart` orquesta la pantalla según el estado y `busqueda_conductor_view.dart` la dibuja:
  - el mensaje de cada etapa de la escalera;
  - la tarjeta de precio sugerido ("Subir a $X" / "Mantener");
  - la tarjeta de cierre (Seguir esperando / Programar / Cancelar sin costo);
  - las ofertas recibidas: `ofertas_recibidas_screen.dart`.
- **Viaje:**
  - `seguimiento_viaje_view.dart` (ruta y ETA del servidor), `conductor_en_la_zona_screen.dart` y `llegada_al_destino_screen.dart`;
  - `chat_screen.dart` y `confirmar_entrega_screen.dart` (confirmar o rechazar → disputa);
  - `calificar_conductor_screen.dart` (se oculta si ya calificó) y `viaje_finalizado.dart`.
- **Mis envíos:** `mis_envios_screen.dart` y `viaje_detalle_screen.dart`. El detalle sirve también para las reservas: desde ahí se cancelan y se responde al pedido de plazo.
- **Soporte:** `soporte_screen.dart` (solo tickets, aviso SOS y preguntas frecuentes) y `shared/tickets/`.
- **Perfil y cuenta:**
  - `perfil_screen.dart`: estadísticas, calificación, portada elegible, editar en pantalla completa (email bloqueado, teléfono obligatorio) y Pagos si tiene deuda;
  - `ajustes_screen.dart`: cambiar contraseña, eliminar cuenta y Acerca de.

### Conductor (`lib/screens/conductor/`)
- **Registro:** `user/registro_conductor/registro_conductor_screen.dart`. Pasos: correo o Google, edad, cédula, foto, vehículo (modelo, tipo, placa, foto), zona y políticas. Termina en "Pendiente de verificación".
- **Inicio:** `home_screen.dart`:
  - interruptor Conectado / Desconectado y ganancias del día;
  - sondeo de 20 s para no perder una oferta aceptada;
  - bloqueo por deuda.
- **Solicitudes:**
  - `solicitudes_disponibles_section.dart` y `solicitudes_disponibles_screen.dart`, con chips de tipo de vehículo y de "Reserva";
  - `hacer_oferta_screen.dart` y `oferta_enviada_screen.dart` (cuenta regresiva), `offers_screen.dart` (Mis ofertas) y `viaje_aceptado_screen.dart`.
- **Viaje en curso:** `trip_in_progress_screen.dart`:
  - fases llegada → foto de recogida → iniciar → cerrar;
  - diálogo "Finalizar entrega" con `CampoPin`, y justificación si está lejos;
  - hoja "Más": información del cliente, reportar y cancelar con motivo;
  - SOS.

  Después vienen `esperando_confirmacion_cliente.dart` y `entrega_confirmada_screen.dart`.
- **Mis reservas:** `mis_reservas_screen.dart`, con "pedir más plazo".
- **Ganancias:** `earnings_screen.dart`:
  - tabla Resumen (Hoy, Semana, Mes y Total; bruto, comisión y neto) y gráfico de la semana;
  - PDF en Descargas;
  - tarjeta de deuda con comprobante. El aviso de la deuda está en `aviso_cuenta_pago.dart`.
- **Otras pantallas:**
  - `documents_screen.dart` (SOAT apagado con `soatActivo = false`) y `grupo_conductores_screen.dart` (avisos, comentarios, líder);
  - `support_screen.dart` (tickets y conversaciones con moderadores) y `reportar_cliente_screen.dart` (30 min después de cerrar);
  - `trip_history_screen.dart`, `profile_screen.dart` (editar, con contacto de emergencia obligatorio), `settings_screen.dart` y `notifications_screen.dart` (bandeja compartida).

### Componentes a reutilizar (`lib/screens/shared/ui_compartida.dart`)
- Colores y tema: `ColoresApp` (no declarar colores locales), `temaApp`, `cifrasTabulares`.
- Contenedores y botones: `TarjetaBlanca` (borde, sin sombra), `BotonPrincipal`/`BotonSecundario`, `BarraInferiorFija`.
- Diálogos y hojas: `DialogoApp`, `HojaApp` + `TituloHoja`, `CajaAviso`, `CajaIcono`, `OpcionRadio`.
- Entrada y estado: `CampoPin`, `ChipEstado`, `ErrorCarga` (en `lib/widgets/`, con Reintentar).
- Vehículos: `VehiculoMapa` / `CapaVehiculos` (`lib/widgets/vehiculo_mapa.dart`).
- Convenciones:
  - `Trip` lee el id de `_id` o de `id`;
  - los botones de abajo van en `bottomNavigationBar` con `SafeArea`;
  - los listeners del socket usan `_trasFrame`;
  - los servicios no importan pantallas.

### Pruebas
- `flutter analyze` y `flutter test` (~736 pruebas, 130 archivos).
- Helper: `test/helpers/fake_api.dart`. Tiene `conApiFalsa(handler, body)` y deja marcados como vistos los tutoriales. También `jsonResp`, `errorResp`, `pantallaAlta` y `avanzar`.
- **Filtrar siempre la salida:** solo los fallos y el resumen.
- APK: `$env:JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"; flutter build apk --release --flavor cliente|conductor`. Después, matar Gradle (el PC es débil).

---

## 4. Panel web (`pagina_express`)
- `src/App.jsx` declara las rutas con `lazy`. `ProtectedRoute area="admin"|"moderator"|"cliente"` restringe el acceso; un admin también puede entrar a `/moderator`.
- `vercel.json` reescribe `/api/*` a Railway y lo demás al SPA. `src/config.js` define `BACKEND_URL` y `SOCKET_URL`.
- `src/api/axios.js` maneja los tokens en localStorage y la renovación ante un 401. El resto de la API está en `src/api/admin.js`, `moderator.js`, `cliente.js` y `tickets.js`.
- Estilos: `src/styles/tokens.css`, `index.css` y `src/styles/ui.css`. Los componentes están en `src/components/ui/` y los mapas en `src/components/maps/`.
- **Páginas públicas:** `/` (Inicio) y `/privacidad`, `/terminos` y `/eliminar-cuenta` (las tres en `Legal.jsx`). El login está en `/ingresar`, `/admin/login` y `/moderator/login`.
- **Admin** (`src/pages/admin/`):
  - Requiere atención: Pendientes, Emergencias, Disputas, Cancelaciones, Tickets y Reportes.
  - Personas:
    - Usuarios, Clientes y Moderadores;
    - Conductores y Mapa de conductores;
    - Verificaciones (documentos y excepción del SOAT).
  - Operación: Viajes, Ganancias, Comisiones y Pagos (comprobantes).
  - Comunicación: Conversatorio, Avisos, Enviar comunicación, Comunicados y Encuestas.
  - Sistema: Configuración (pestañas Pagos/Nequi, Cobertura, Banner y **Búsqueda = escalera**), Respaldos y Perfil.
- **Moderador** (`src/pages/moderator/`, filtrado por la ciudad del moderador):
  - Centro de control, Emergencias, Cierres, Tickets, Viajes y Reservas;
  - Conductores (verificar) e Inactivos;
  - Conversaciones, Compañeros, Avisos, Comunicados y Encuestas.
- **Cliente web** (`src/pages/cliente/`): viaje activo con mapa en vivo (`MapaViaje.jsx`, `VehiculoMarcador.js`), Mis viajes y Soporte.
- Build con `npm run build`. Se publica **solo** con push a `main` de `Vectogv/Pagina-carga-express`; nunca `vercel deploy` ni otro proyecto.

---

## 5. Cómo se trabaja (resumen; las reglas completas están en `CLAUDE.local.md` §0)
- Responder en español. El servidor es la regla.
- Commits:
  - en español;
  - el mensaje se escribe en un archivo UTF-8 sin BOM y se usa `git commit -F`;
  - la última línea es `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Servidor:**
  - se despliega solo con opencode (`railway up`, script `%TEMP%\e2e\oc_deploy*.ps1`);
  - después se comprueba `railway deployment list` y que `/health` dé 200.
- **Pruebas en vivo:**
  - Emulador `CargaExpress` (cliente). En una sesión remota se arranca con `-gpu swiftshader_indirect -no-window`.
  - El conductor se maneja por API con los scripts de `%TEMP%\e2e`.
  - Antes de iniciar o cerrar un viaje por API, poner el GPS con `adb emu geo fix`.
- Todo lo que se hace queda en "Por probar" (§7.P de `CLAUDE.local.md`) hasta verlo funcionar en vivo.
