# Guía de Pruebas de Integración (E2E)

## Requisitos

- **Flutter 3.x** instalado
- **Emulador de Android** (Pixel 6 API 33+ recomendado) o dispositivo físico
- No se necesita Firebase para pruebas (el mock server reemplaza el backend)

## Estructura

```
integration_test/
├── flujo_completo_test.dart   # Test E2E: login cliente → solicitar → conductor → finalizar
├── mock_server.dart           # Servidor HTTP mock en localhost:3333
└── test_utils.dart            # Helpers: login, enterTextByLabel, tapButton
```

## Cómo ejecutar

### 1. Desde VSCode (recomendado)

| Acción | Cómo |
|--------|------|
| **Ejecutar test** | `Ctrl+Shift+P` → "Tasks: Run Task" → "E2E: Flujo completo" |
| **Debuggear test** | Abrir `integration_test/flujo_completo_test.dart` → F5 (seleccionar "E2E: Flujo completo (debug)") |
| **Todos los tests** | `Ctrl+Shift+P` → "Tasks: Run Task" → "E2E: Todos los tests de integración" |

### 2. Desde terminal

```bash
# Test individual (recomendado)
flutter test integration_test/flujo_completo_test.dart --dart-define=TEST_MODE=true --reporter expanded

# Todos los tests de integración
flutter test integration_test/ --dart-define=TEST_MODE=true --reporter expanded
```

### 3. Usando el script npm

```bash
npm run test:e2e
```

## Qué hace el flag `--dart-define=TEST_MODE=true`

Cambia la URL base de la API de `http://localhost:3333` a `http://10.0.2.2:3333` para que
la app dentro del emulador Android pueda alcanzar el mock server que corre en tu máquina host.

## Flujo de la prueba

1. Inicia la app (auth landing)
2. Inicia sesión como cliente (`cliente@test.com` / `123456`)
3. Solicita un viaje
4. Se simula una oferta del conductor (vía mock server)
5. Se cierra sesión del cliente
6. Inicia sesión como conductor (`conductor@test.com` / `123456`)
7. El conductor navega al viaje activo
8. Finaliza el viaje
9. Se verifica el estado final

## Solución de problemas

### "Target of URI doesn't exist: 'package:integration_test/...'"

Ejecuta `flutter pub get` para instalar la dependencia.

### "Connection refused" o timeout

1. Verifica que el mock server no tenga el puerto ocupado:
   ```bash
   netstat -ano | findstr :3333
   ```
2. Mata procesos viejos:
   ```bash
   taskkill /F /PID <PID>
   ```

### El emulador no aparece

```bash
flutter devices
```
Si no aparece, abre Android Studio → Tools → AVD Manager → inicia el emulador.

### El test falla en "Iniciar Sesion"

Limpia los datos de SharedPreferences del emulador:
```bash
adb shell pm clear com.example.cargaexpress
```

## Comandos rápidos

| Comando | Descripción |
|---------|-------------|
| `flutter test integration_test/ --dart-define=TEST_MODE=true` | Corre todos los E2E |
| `flutter test --dart-define=TEST_MODE=true integration_test/flujo_completo_test.dart --reporter expanded` | Test individual con detalle |
| `flutter analyze lib/` | Verifica que lib/ no tenga errores |
| `flutter test` | Corre solo tests unitarios (sin emulador) |
