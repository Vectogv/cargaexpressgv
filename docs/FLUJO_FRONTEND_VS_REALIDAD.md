# Análisis de Brecha: Documentación de Flujo vs Implementación Real

**Fecha:** 26/06/2026
**Proyecto:** CargaExpress GV
**Propósito:** Documentar todo lo que NO funciona o NO existe respecto al flujo documentado, para que el equipo sepa qué hay que implementar/corregir.

---

## 1. ESTADOS DEL VIAJE — Backend

### Problema principal
El documento describe 10 estados en inglés, pero el backend usa 8 estados en español. No hay correspondencia 1:1.

### Backend actual (8 estados)
| Estado real | Descripción |
|---|---|
| `buscando_conductor` | Buscando conductor disponible |
| `pendiente` | Ofertas siendo revisadas |
| `aceptado` | Conductor asignado |
| `en_curso` | Viaje en progreso |
| `completado` | Carga entregada, pendiente de cierre financiero |
| `finalizado` | Cerrado financieramente (terminal) |
| `cancelado` | Cancelado (terminal) |
| `rechazado` | Rechazado por conductor (terminal) |

### Lo que el documento espera y NO existe
| Estado documento | Estado real | Acción requerida |
|---|---|---|
| `CREATED` | No existe | Crear estado o mapear a `buscando_conductor` |
| `SEARCHING_DRIVER` | `buscando_conductor` | Solo renombrar (o mapear) |
| `OFFERS_RECEIVED` | No existe | Crear nuevo estado para cuando hay ≥1 oferta |
| `DRIVER_ACCEPTED` | `aceptado` | Solo renombrar (o mapear) |
| `DRIVER_GOING_PICKUP` | No existe | Crear nuevo estado (separado de `aceptado`) |
| `DRIVER_ARRIVED` | No existe | Crear nuevo estado |
| `TRIP_IN_PROGRESS` | `en_curso` | Solo renombrar (o mapear) |
| `DELIVERED` | `completado` | Solo renombrar (o mapear) |
| `WAITING_CONFIRMATION` | No existe | Crear nuevo estado |
| `COMPLETED` | `finalizado` | Solo renombrar (o mapear) |
| `SOS` | No existe (es entidad aparte) | Decidir si será estado del viaje o se queda como entidad separada |
| `DISPUTE` | No existe (es entidad aparte) | Decidir si será estado del viaje o se queda como entidad separada |
| `RESOLVED` | No existe (es estado de dispute) | Decidir según decisión anterior |

### Acción recomendada
**Opción A (mínima):** Actualizar el documento para que coincida con los 8 estados reales del backend.
**Opción B (completa):** Agregar los 5 estados faltantes al backend y actualizar la máquina de estados.

Si se elige la Opción B, la máquina de estados quedaría:
```
CREATED → SEARCHING_DRIVER → OFFERS_RECEIVED → DRIVER_ACCEPTED → DRIVER_GOING_PICKUP → DRIVER_ARRIVED → TRIP_IN_PROGRESS → DELIVERED → WAITING_CONFIRMATION → COMPLETED
                                                                                                                   ↘ DISPUTE → RESOLVED → COMPLETED
Cualquier estado intermedio ↘ CANCELLED (según reglas de distancia)
SOS disponible desde DRIVER_ACCEPTED hasta TRIP_IN_PROGRESS
```

---

## 2. REGLAS DE CANCELACIÓN — No existen

### Lo que el documento dice
| Distancia | Puede cancelar | Penalización |
|---|---|---|
| > 1 km | Sí | Sin penalización (primera vez) |
| 1 – 2 km | Sí (con advertencia) | Aviso de impacto en reputación |
| < 1 km | **NO** | Botón desactivado |

### Lo que realmente hay
- Backend: Cliente puede cancelar solo si NO hay conductor asignado (`buscando_conductor` o `pendiente`)
- Conductor puede cancelar solo si está en `aceptado`
- Solo admin cancela viajes `en_curso`
- **No existe** ninguna lógica de distancia para cancelación
- **No existe** penalización por reputación ligada a distancia
- Solo existe un threshold de 0.5km para notificación "conductor cerca" (no para bloqueo de cancelación)

### Acción requerida
1. Agregar campo `distanciaCancelacion` o consultar distancia en tiempo real al取消
2. Implementar lógica en backend:
   - Calcular distancia conductor → cliente al momento de cancelar
   - Bloquear cancelación si < 1km (devolver error 403)
   - Aplicar penalización de reputación si 1-2km
3. Agregar mensajes de advertencia específicos según distancia
4. Endpoint o campo en `GET /api/trips/active` que indique si la cancelación está permitida

---

## 3. TEMPORIZADOR DE OFERTA (28 segundos) — No existe

### Lo que el documento dice
El conductor tiene 28 segundos para responder a una solicitud de viaje. Si no responde, la solicitud expira.

### Lo que realmente hay
- **No existe** ningún temporizador de expiración de ofertas
- Las ofertas quedan en estado `pendiente` indefinidamente
- Solo se cancelan cuando el conductor hace una nueva oferta (se cancela la anterior) o el cliente acepta/rechaza

### Acción requerida
1. Agregar campo `expiraAt` a la tabla `ofertas`
2. Implementar un job/scheduler (o validación en backend) que expire ofertas automáticamente
3. Emitir evento `offer:expired` por socket cuando una oferta venza
4. En frontend: mostrar countdown de 28s en la pantalla del conductor
5. El valor de 28s debería ser configurable desde `configuracion_plataforma`

---

## 4. EVENTOS SOCKET.IO — Nombres incorrectos/faltantes

### Lo que el documento lista vs lo que realmente existe

| Documento | Realidad | Acción |
|---|---|---|
| `trip:new_request` | ❌ No existe | Crear evento o renombrar `trip:nearby` |
| `trip:offer_received` | ❌ No existe | Crear evento o renombrar `new:offer` |
| `trip:offer_accepted` | ❌ No existe (backend emite `offer:accepted`) | Decidir nomenclatura y unificar |
| `trip:status_changed` | ❌ No existe (backend emite `trip:status`) | Decidir nomenclatura y unificar |
| `driver:location` | ✅ Existe igual | — |
| `trip:driver_arrived` | ❌ No existe | Crear evento (actualmente se calcula por proximidad en frontend) |
| `trip:delivered` | ❌ No existe (backend emite `trip:finalized`) | Crear evento o renombrar |
| `trip:completed` | ❌ No existe (backend emite `trip:finalized`) | Decidir nomenclatura y unificar |
| `dispute:created` | ❌ No existe (backend emite `dispute:updated` + `admin:new_dispute`) | Crear evento específico |
| `dispute:resolved` | ✅ Existe igual | — |
| `sos:activated` | ❌ No existe (backend emite `admin:emergency`) | Crear evento o renombrar |
| `trip:cancelled` | ✅ Existe igual | — |

### Eventos adicionales que backend emite pero el documento no menciona
- `trip:nearby` — viajes cercanos para conductores
- `offer:accepted` — conductor notificado que su oferta fue aceptada
- `offer:rejected` — conductor notificado que su oferta fue rechazada
- `trip:started` — viaje inició (conductor en camino)
- `trip:finalized` — viaje finalizado financieramente
- `trip:gps_frozen` — alerta de GPS congelado
- `trip:eta_update` — actualización de tiempo estimado
- `trip:driver_nearby` — conductor está cerca
- `message:new` / `typing:start` / `typing:stop` / `message:read` — eventos de chat
- `driver:stop_gps` — detener envío de GPS

### Acción requerida
1. Unificar nomenclatura: decidir si se usa `tipo:accion` (ej: `trip:cancelled`) o `tipo:accion_en_pasado` consistente
2. Crear eventos faltantes en backend: `trip:driver_arrived`, `trip:delivered` (si se agregan esos estados), `dispute:created`, `sos:activated`
3. Actualizar frontend para escuchar los eventos correctos
4. Documentar todos los eventos en un solo lugar

---

## 5. FLUJO DE DISPUTAS — Diferencias

| Aspecto | Documento | Realidad |
|---|---|---|
| ¿Quién crea? | Solo cliente | Ambos (cliente y conductor) |
| Estado requerido del viaje | `DELIVERED` | `finalizado` |
| Estados de disputa | No especifica | `abierta` → `en_revision` → `resuelta` |
| Notificación al otro participante | No especifica | Sí, ambos reciben `dispute:updated` y `dispute:resolved` |
| Resultados | No especifica | `favor_conductor` o `favor_cliente` con side-effects (deuda, suspensión, observación) |

### Acción requerida
1. Decidir si la disputa se puede crear desde `DELIVERED` o solo desde `finalizado` (como está ahora)
2. Si se cambia a `DELIVERED`, actualizar el backend para permitirlo
3. Documentar correctamente los estados y el flujo completo de disputa

---

## 6. FLUJO SOS — Diferencias

| Aspecto | Documento | Realidad |
|---|---|---|
| ¿Quién activa? | Cliente o conductor | Cualquier usuario autenticado |
| ¿Requiere viaje activo? | Sí | No (opcional) |
| Motivo | Robo, Accidente, Agresivo, Otro | No se almacena motivo |
| ¿A quién notifica? | Admin | Solo admin (socket + FCM) |
| Estado del viaje | Cambia a SOS | No cambia estado del viaje |
| Resolución | Admin gestiona y cierra | Admin marca `atendida = true` |

### Acción requerida
1. Decidir si el SOS requiere viaje activo o no
2. Agregar campo `motivo` a `alertas_emergencia` con los valores del documento
3. Si se decide que SOS debe cambiar estado del viaje, agregar lógica en backend
4. Agregar evento `sos:activated` a client/driver (no solo admin)
5. Una vez resuelto, enviar notificación al usuario que activó el SOS

---

## 7. PANTALLAS DEL FRONTEND — Faltantes

### Cliente — Pantallas que no existen como tal

| # | Documento | Realidad | Acción |
|---|---|---|---|
| 3 | Buscando conductores | Solo es un texto de estado dentro de `RastreoScreen` | Crear pantalla independiente con animación de búsqueda |
| 10 | Viaje en curso (cliente) | Solo es una fase dentro de `RastreoScreen` | Crear pantalla independiente o separar visualmente las fases |

### Conductor — Pantallas que no existen

| # | Documento | Realidad | Acción |
|---|---|---|---|
| 2 | Solicitud de viaje recibida | No hay pantalla dedicada; la info está en `OffersScreen` y `ConductorTripDetailScreen` | Crear pantalla full-screen con temporizador de 28s |
| 8 | Cancelar viaje (motivo) | Solo hay callbacks `onCancelarViaje` embebidos en otras pantallas | Crear pantalla independiente con radio buttons y comentario |
| 10 | Cancelación bloqueada | No existe en ningún lado | Crear pantalla de error informativa |
| 24 | Disputa finalizada | No existe; el wrapper navega directo al home | Crear pantalla de cierre con check verde |

### Pantallas con nombre diferente al documento

| Documento dice | Código real | Archivo |
|---|---|---|
| Alerta de cercanía / Advertencia de proximidad | `DriverNearbyWarningSheet` | `widgets/driver_nearby_warning_sheet.dart` (es un bottom sheet, no pantalla) |
| Enviar evidencia (conductor #21) | `MiVersionScreen` | `screens/conductor/mi_version_screen.dart` |
| Conductor llega al punto (cliente #9) | `ConductorEnLaZonaScreen` | `screens/cliente/conductor_en_la_zona_screen.dart` |

### Acción requerida
1. Crear las 5 pantallas faltantes
2. Unificar nombres entre documento y código (o actualizar documento)
3. Decidir si "Alerta de cercanía" será un bottom sheet reutilizable o pantalla completa

---

## 8. GO ROUTER — No se usa

### Problema
`core/routes.dart` define un `GoRouter` con rutas declarativas, pero `main.dart` usa `MaterialApp` con navegación imperativa (`Navigator.push`). El GoRouter es código muerto.

### Acción requerida
1. **Opción A:** Eliminar `core/routes.dart` y seguir usando navegación imperativa
2. **Opción B:** Migrar `main.dart` a `MaterialApp.router` y reemplazar todos los `Navigator.push` por `context.go()` / `context.push()`

---

## 9. AUTO-NAVEGACIÓN POR SOCKET — Inconsistente

### Problema
El documento dice: "Al recibir `trip:status_changed`, evaluar el nuevo estado y navegar a la pantalla correspondiente."

En la realidad:
- `home_screen.dart` (cliente) escucha `trip:status` y solo refresca datos, no navega automáticamente
- `rastreo_screen.dart` escucha eventos individuales (`offer:accepted`, `trip:accepted`, `trip:started`, etc.) y navega según cada uno
- No hay un manejador centralizado de auto-navegación

### Acción requerida
1. Implementar un servicio/mixin que escuche `trip:status` (o `trip:status_changed`) y navegue automáticamente según el estado
2. Esto también resuelve el caso de "usuario cierra y reabre la app" — consultar `GET /api/trips/active` en `main.dart` o `home_screen.dart` y navegar al estado correcto

---

## 10. VERIFICACIONES ADICIONALES

### Lo que el documento pide y no se verifica

| Regla | Estado |
|---|---|
| Subir evidencias ANTES de habilitar "He llegado al destino" | ❌ No verificado en backend |
| Botón SOS visible en TODAS las pantallas de viaje activo | ❌ Depende de cada screen |
| Actualizar GPS del conductor cada 3-5 segundos | ✅ Existe (cada 4s por rate-limit) |
| Calcular y mostrar tiempo/distancia restante | ⚠️ Parcial: backend calcula ETA, frontend lo muestra |

### Recomendaciones adicionales
- Agregar validación en backend: `POST /api/trips/:id/complete` debe requerir que se haya subido foto de evidencia primero
- Crear un `SOSButton` widget reutilizable para incluirlo en todas las pantallas de viaje activo
- Centralizar la lógica de "distancia para cancelar" en un solo lugar

---

## RESUMEN DE ACCIONES PRIORIZADAS

| Prioridad | Acción | Área |
|---|---|---|
| 🔴 Alta | Unificar nomenclatura de estados del viaje (inglés vs español) | Backend + Documento |
| 🔴 Alta | Implementar reglas de cancelación por distancia | Backend + Frontend |
| 🔴 Alta | Implementar temporizador de 28s en ofertas | Backend + Frontend |
| 🔴 Alta | Corregir nombres de eventos Socket.IO en backend y frontend | Backend + Frontend |
| 🟡 Media | Crear 5 pantallas faltantes (conductor: solicitud, cancelar, bloqueo, disputa finalizada; cliente: buscando) | Frontend |
| 🟡 Media | Decidir y unificar el GoRouter o eliminarlo | Frontend |
| 🟡 Media | Agregar motivo a SOS y notificar a conductor/cliente | Backend |
| 🟢 Baja | Actualizar documento para reflejar la realidad del flujo de disputas | Documento |
| 🟢 Baja | Centralizar auto-navegación por socket | Frontend |
