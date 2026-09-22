# LOTE 2 + LOTE 3 — Final Report

## Validation Results
- **Backend `node ace test`**: 108 passed / 0 failed ✅
- **Flutter `flutter analyze`**: 0 errors, 25 infos (pre-existing style) ✅
- **Flutter `flutter test`**: 157 passed / 0 failed ✅

---

## Items Table

| ID | Description | Status | Files Touched (Key) |
|----|-------------|--------|---------------------|
| **A** | Re-offer cancels previous offer → emits `offer:cancelled` to client | ✅ Done | `offer_controller.ts` (store) |
| **B** | Oferta accepts `placa`/`mensaje`; payload includes `_id`, `rating`, `placa`, `mensaje`, `expiresAt`, `createdAt`; index returns same | ✅ Done | `offer_controller.ts` (store, index), `app/models/oferta.ts`, `database/migrations/1788701000000_add_placa_mensaje_to_ofertas.ts` |
| **10** | Offer accept validates `expiraAt` → 422 `OFERTA_EXPIRADA` if expired | ✅ Done | `offer_controller.ts` (accept) |
| **11** | `emitTripStatusChanged` helper emits `trip:status` + `trip:status_changed` to client & driver on accept/start/complete/finalize/cancel | ✅ Done | `start/socket.ts` (helper), `offer_controller.ts`, `trip_controller.ts` |
| **12** | Test: aceptar oferta expirada → 422, no asigna conductor | ✅ Done | `tests/functional/lote2_qa.spec.ts` (Lote2 - Oferta expirada) |
| **13** | Test: GET `/api/notifications` expone aliases `_id`, `type`, `title`, `body`, `read` | ✅ Done | `notification_controller.ts` (index), `transformers/notificacion_transformer.ts`, `tests/functional/lote2_qa.spec.ts` |
| **14** | PUT `/api/notifications/:id/read` emite `notification:read` para badge in-app | ✅ Done | `notification_controller.ts` (read) |
| **15** | Notificación: ajeno 404; Emergencia: no-participante 403 `No participas en este viaje` | ✅ Done | `notification_controller.ts` (read), `emergency_controller.ts` (trigger), `tests/functional/lote2_qa.spec.ts` |
| **16** | Refresh token inválido → 401 (era 200); token ya rotado no reutilizable → 401; validador `edad` ≥ 18 | ✅ Done | `auth_controller.ts` (refreshToken), `validators/auth.ts`, `tests/functional/auth.spec.ts`, `tests/functional/lote2_qa.spec.ts` |
| **18** | `trip_dispatch_service`: elimina filtro `fcm_token` (socket a todos cercanos); payload con `_id`, `viajeId`, `tipoProgramacion`, `programada` | ✅ Done | `services/trip_dispatch_service.ts` |
| **19** | Protocolo socket alineado: `trip:status`/`trip:status_changed` (ambos), `notification:read`, `sos:activated` con `id` + `viajeId` | ✅ Done | `start/socket.ts`, `notification_controller.ts`, `emergency_controller.ts` |
| **20** | `TripController.formatViajeResponse`: `descripcion`, `tiempoEstimado`, `tiempoEstimadoMinutos` (nullable), `precioEstimado`/`precioFinal` (nullable) | ✅ Done | `trip_controller.ts` |
| **21** | `TripStatus.reservado` constante + labels en `viaje_detalle`, `trip_history`, `home_screen`, `offers_screen` | ✅ Done | `contracts/trip_status.dart`, `screens/cliente/viaje_detalle_screen.dart`, `screens/conductor/trip_history_screen.dart`, `screens/conductor/home_screen.dart`, `screens/conductor/offers_screen.dart` |
| **22** | Driver uploads (vehicle-photo, driver-photo, cedula, licencia, vehiculo) → 400 `No file uploaded` | ✅ Done | `driver_controller.ts`, `tests/functional/drivers.spec.ts` (5 tests actualizados 200→400) |
| **23** | `TripService.getActiveTrip` + `DriverService.getEarningsPdf` usan `HttpClient` (shared refresh + `getBytes` para PDF) | ✅ Done | `services/api/http_client.dart`, `services/api/trip_service.dart`, `services/api/driver_service.dart` |
| **24** | Oferta payload ya incluye `placa`/`mensaje` (B ya los acepta, F ya los envía) | ✅ Done | `offer_controller.ts` (store), `lib/services/api/offer_service.dart` (F) |
| **25** | Validador `auth`: `edad` number ≥ 18 nullable/optional | ✅ Done | `validators/auth.ts` |

---

## Additional Fixes (Supporting)
| Item | Description | Files |
|------|-------------|-------|
| Dispute uploadSupport | Solo PDF ≤ 2MB → 422; sin archivo → 400 | `dispute_controller.ts` |
| Response bodies 401/404 | Cambiados `serialize.withoutWrapping` → `.json()` para evitar cuerpo vacío `{}` | `auth_controller.ts`, `notification_controller.ts`, `dispute_controller.ts` |
| Notificación insert test | Usa modelo `Notificacion` en lugar de `db.from().insert()` | `tests/functional/lote2_qa.spec.ts` |

---

## Notes
- **Admin items skipped per instruction**: C (admin:stats/admin:client:location), 17 (mapa vivo), admin:join handler — no changes made.
- **LOTE 1 admin work preserved**: No reverts.
- **Payment/Profile uploads untouched**: `payment_controller.ts`, `profile_controller.ts` not modified.
- **Flutter analyze infos**: 25 pre-existing style warnings (BuildContext async gaps, deprecated Radio API, etc.) — no new issues introduced.