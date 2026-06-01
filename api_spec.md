# API CargaExpress GV

## Tech Stack Recomendado

| Capa | Opción |
|------|--------|
| Lenguaje | Node.js (Express) o Python (FastAPI) |
| Base de datos | PostgreSQL |
| Autenticación | JWT + refresh tokens |
| Archivos | Cloudinary o S3 (fotos perfil/vehículo) |
| Tiempo real | Socket.io o WebSockets (viajes en vivo) |
| Mapas | Mapbox / Google Maps API |

---

## Autenticación

### POST /api/auth/register

```json
// Request
{
  "nombre": "Carlos",
  "apellido": "Mendoza",
  "email": "carlos@email.com",
  "password": "123456",
  "telefono": "+584121234567",
  "rol": "conductor" | "cliente",
  // si rol = conductor:
  "edad": 32,
  "cedula": "V-12.345.678",
  "placa": "ABC-123"
}

// Response 201
{
  "id": "uuid",
  "nombre": "Carlos",
  "apellido": "Mendoza",
  "email": "carlos@email.com",
  "rol": "conductor",
  "token": "jwt_access_token",
  "refreshToken": "jwt_refresh_token"
}
```

### POST /api/auth/login

```json
// Request
{
  "email": "carlos@email.com",
  "password": "123456"
}

// Response 200
{
  "id": "uuid",
  "nombre": "Carlos",
  "apellido": "Mendoza",
  "email": "carlos@email.com",
  "rol": "conductor",
  "token": "jwt_access_token",
  "refreshToken": "jwt_refresh_token"
}
```

### POST /api/auth/refresh-token

```json
// Request
{
  "refreshToken": "jwt_refresh_token"
}

// Response 200
{
  "token": "new_jwt_access_token",
  "refreshToken": "new_jwt_refresh_token"
}
```

---

## Perfil

### GET /api/users/profile

```json
// Response 200
{
  "id": "uuid",
  "nombre": "Carlos",
  "apellido": "Mendoza",
  "email": "carlos@email.com",
  "telefono": "+584121234567",
  "edad": 32,
  "avatar": "https://...",
  "rol": "conductor",
  "conductor": {
    "cedula": "V-12.345.678",
    "placa": "ABC-123",
    "fotoConductor": "https://...",
    "fotoVehiculo": "https://...",
    "calificacion": 4.9,
    "viajes": 0,
    "horasActivo": 0.0
  }
}
```

### PUT /api/users/profile

```json
// Request
{
  "nombre": "Carlos",
  "apellido": "Mendoza",
  "email": "carlos@email.com",
  "telefono": "+584121234567",
  "edad": 32
}

// Response 200
{
  "id": "uuid",
  "nombre": "Carlos",
  "apellido": "Mendoza",
  "email": "carlos@email.com",
  "telefono": "+584121234567",
  "edad": 32
}
```

### POST /api/users/avatar
multipart/form-data: `file` (imagen)

```json
// Response 200
{ "avatar": "https://..." }
```

---

## Conductores

### PUT /api/drivers/status

```json
// Request
{ "online": true }

// Response 200
{ "online": true, "updatedAt": "2026-05-28T12:00:00Z" }
```

### GET /api/drivers/earnings

```json
// Response 200
{
  "hoy": 125.50,
  "semana": 850.00,
  "mes": 3450.00,
  "total": 12450.00
}
```

### GET /api/drivers/stats

```json
// Response 200
{
  "viajes": 47,
  "horasActivo": 38.5,
  "calificacion": 4.9,
  "totalReviews": 42
}
```

### POST /api/drivers/vehicle-photo
multipart/form-data: `file`

```json
// Response 200
{ "fotoVehiculo": "https://..." }
```

### POST /api/drivers/driver-photo
multipart/form-data: `file`

```json
// Response 200
{ "fotoConductor": "https://..." }
```

---

## Viajes

### POST /api/trips/request

```json
// Request
{
  "origen": {
    "direccion": "Av. Principal, Los Palos Grandes",
    "lat": 10.4806,
    "lng": -66.9036
  },
  "destino": {
    "direccion": "Zona Industrial, Boleíta",
    "lat": 10.4700,
    "lng": -66.8900
  },
  "descripcion": "Caja de repuestos - 15 kg"
}

// Response 201
{
  "id": "uuid",
  "estado": "buscando_conductor",
  "clienteId": "uuid",
  "origen": { ... },
  "destino": { ... },
  "precioEstimado": 35.00,
  "createdAt": "2026-05-28T12:00:00Z"
}
```

### GET /api/trips/nearby?lat=10.4806&lng=-66.9036&radio=5

```json
// Response 200
[
  {
    "id": "uuid",
    "cliente": {
      "nombre": "María García",
      "calificacion": 4.8
    },
    "origen": {
      "direccion": "Av. Libertador, Chacao",
      "lat": 10.4850,
      "lng": -66.8980
    },
    "destino": {
      "direccion": "Zona Industrial, Boleíta",
      "lat": 10.4700,
      "lng": -66.8900
    },
    "carga": "Caja de repuestos - 15 kg",
    "precioEstimado": 35.00,
    "distancia": 2.3,
    "createdAt": "2026-05-28T12:00:00Z"
  }
]
```

### GET /api/trips/active

```json
// Response 200
{
  "id": "uuid",
  "estado": "aceptado" | "en_curso" | "completado",
  "cliente": { "id": "uuid", "nombre": "María García", "telefono": "...", "avatar": "..." },
  "conductor": { "id": "uuid", "nombre": "Carlos Mendoza", "telefono": "...", "placa": "ABC-123" },
  "origen": { "direccion": "...", "lat": 10.4850, "lng": -66.8980 },
  "destino": { "direccion": "...", "lat": 10.4700, "lng": -66.8900 },
  "precio": 35.00,
  "tiempoEstimado": 12,
  "createdAt": "2026-05-28T12:00:00Z",
  "aceptadoAt": "2026-05-28T12:01:00Z",
  "completadoAt": null
}
// Si no hay viaje activo → 404
```

### POST /api/trips/:id/accept

```json
// Response 200
{
  "id": "uuid",
  "estado": "aceptado",
  "aceptadoAt": "2026-05-28T12:01:00Z"
}
```

### POST /api/trips/:id/decline

```json
// Response 200
{ "id": "uuid", "estado": "rechazado" }
```

### POST /api/trips/:id/complete

```json
// Request
{ "montoFinal": 35.00 }

// Response 200
{
  "id": "uuid",
  "estado": "completado",
  "montoFinal": 35.00,
  "completadoAt": "2026-05-28T12:30:00Z"
}
```

### POST /api/trips/:id/cancel

```json
// Request
{ "motivo": "cambio_de_planes" }

// Response 200
{
  "id": "uuid",
  "estado": "cancelado",
  "canceladoAt": "2026-05-28T12:05:00Z"
}
```

### GET /api/trips/history?page=1&limit=20

```json
// Response 200
{
  "data": [
    {
      "id": "uuid",
      "estado": "completado",
      "origen": "Av. Principal...",
      "destino": "Zona Industrial...",
      "monto": 35.00,
      "fecha": "2026-05-28T12:30:00Z",
      "conductor": { "nombre": "Carlos Mendoza", "placa": "ABC-123" }
    }
  ],
  "total": 47,
  "page": 1,
  "limit": 20
}
```

### GET /api/trips/:id

```json
// Response 200
{
  "id": "uuid",
  "estado": "completado",
  "cliente": { "id": "uuid", "nombre": "María García", "telefono": "..." },
  "conductor": { "id": "uuid", "nombre": "Carlos Mendoza", "telefono": "...", "placa": "ABC-123" },
  "origen": { "direccion": "...", "lat": 10.4850, "lng": -66.8980 },
  "destino": { "direccion": "...", "lat": 10.4700, "lng": -66.8900 },
  "carga": "Caja de repuestos - 15 kg",
  "precio": 35.00,
  "createdAt": "2026-05-28T12:00:00Z",
  "aceptadoAt": "2026-05-28T12:01:00Z",
  "completadoAt": "2026-05-28T12:30:00Z"
}
```

---

## Notificaciones

### GET /api/notifications

```json
// Response 200
[
  {
    "id": "uuid",
    "tipo": "nuevo_viaje" | "viaje_aceptado" | "viaje_completado" | "pago_recibido",
    "titulo": "Nuevo viaje disponible",
    "mensaje": "Solicitud de envío a 2.3 km",
    "leido": false,
    "createdAt": "2026-05-28T11:55:00Z"
  }
]
```

### PUT /api/notifications/:id/read

```json
// Response 200
{ "id": "uuid", "leido": true }
```

---

## Soporte

### GET /api/support/help
```json
// Response 200
{
  "faq": [
    { "pregunta": "¿Cómo me registro?", "respuesta": "..." },
    { "pregunta": "¿Cómo funciona el pago?", "respuesta": "..." }
  ],
  "contacto": {
    "email": "soporte@cargaexpress.com",
    "telefono": "+58 800-CARGA"
  }
}
```

### GET /api/support/emergency
```json
// Response 200
{
  "numeros": [
    { "nombre": "Emergencias", "numero": "911" },
    { "nombre": "Tránsito terrestre", "numero": "0800-TRANSITO" },
    { "nombre": "Asistencia vial", "numero": "0500-ASISTENCIA" },
    { "nombre": "Soporte CargaExpress", "numero": "+58 800-CARGA" }
  ]
}
```

---

## WebSockets (tiempo real)
```
Eventos del socket (conductor):
  connect
  join:driver:{userId}
  trip:nearby          → data: { id, cliente, origen, precio }
  trip:request         → data: { id, cliente, origen, destino, carga }
  trip:accepted        → data: { id, estado: "aceptado" }
  trip:completed       → data: { id, estado: "completado", monto }
  trip:cancelled       → data: { id, estado: "cancelado" }

Eventos del socket (cliente):
  connect
  join:client:{userId}
  trip:status          → data: { id, estado, conductor, tiempoEstimado }
  driver:location      → data: { lat, lng }  (actualización cada 5s)
  trip:completed       → data: { id, monto }
  trip:cancelled       → data: { id, motivo }
```

---

## Modelo de Base de Datos (PostgreSQL)

```sql
CREATE TABLE usuarios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre VARCHAR(100) NOT NULL,
  apellido VARCHAR(100) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  telefono VARCHAR(20),
  edad INT,
  avatar TEXT,
  rol VARCHAR(20) NOT NULL CHECK (rol IN ('conductor', 'cliente')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE conductores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID UNIQUE NOT NULL REFERENCES usuarios(id),
  cedula VARCHAR(20) UNIQUE NOT NULL,
  placa VARCHAR(20) UNIQUE NOT NULL,
  foto_conductor TEXT,
  foto_vehiculo TEXT,
  online BOOLEAN DEFAULT false,
  calificacion DECIMAL(2,1) DEFAULT 0.0,
  total_viajes INT DEFAULT 0,
  horas_activo DECIMAL(5,1) DEFAULT 0.0,
  ultima_ubicacion_lat DECIMAL(10,7),
  ultima_ubicacion_lng DECIMAL(10,7),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE viajes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cliente_id UUID NOT NULL REFERENCES usuarios(id),
  conductor_id UUID REFERENCES conductores(id),
  estado VARCHAR(20) NOT NULL CHECK (estado IN (
    'buscando_conductor', 'aceptado', 'en_curso', 'completado', 'cancelado', 'rechazado'
  )),
  origen_direccion TEXT NOT NULL,
  origen_lat DECIMAL(10,7) NOT NULL,
  origen_lng DECIMAL(10,7) NOT NULL,
  destino_direccion TEXT NOT NULL,
  destino_lat DECIMAL(10,7) NOT NULL,
  destino_lng DECIMAL(10,7) NOT NULL,
  carga TEXT,
  precio_estimado DECIMAL(10,2),
  precio_final DECIMAL(10,2),
  motivo_cancelacion TEXT,
  calificacion_cliente INT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  aceptado_at TIMESTAMPTZ,
  completado_at TIMESTAMPTZ,
  cancelado_at TIMESTAMPTZ
);

CREATE TABLE notificaciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID NOT NULL REFERENCES usuarios(id),
  tipo VARCHAR(50) NOT NULL,
  titulo VARCHAR(255) NOT NULL,
  mensaje TEXT,
  leido BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE ganancias (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conductor_id UUID NOT NULL REFERENCES conductores(id),
  viaje_id UUID REFERENCES viajes(id),
  monto DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_viajes_estado ON viajes(estado);
CREATE INDEX idx_viajes_conductor ON viajes(conductor_id);
CREATE INDEX idx_notificaciones_usuario ON notificaciones(usuario_id);
CREATE INDEX idx_ganancias_conductor ON ganancias(conductor_id);
```
