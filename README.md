# CUPPO

Marketplace para reservar canchas deportivas (fútbol, pádel, tenis, vóley, básquet, béisbol, pickleball...).

```
[App móvil .NET MAUI]  ──HTTPS/JSON──►  [ApiCoreCUPPO (ASP.NET Core 10)]  ──Dapper──►  [SQL Server]
```

## Estructura

| Carpeta | Contenido |
|---|---|
| `ApiCoreCUPPO/ApiCoreCUPPO/ApiCoreCUPPO.slnx` | Solución de la API |
| `ApiCoreCUPPO.Domain` | Entidades (sin dependencias) |
| `ApiCoreCUPPO.Application` | DTOs, interfaces y servicios (lógica de negocio) |
| `ApiCoreCUPPO.Infrastructure` | Repositorios Dapper, JWT |
| `ApiCoreCUPPO.Shared` | Contratos compartidos con la app móvil (vacío por ahora) |
| `ApiCoreCUPPO` | API: controladores, `Program.cs` |
| `Database/` | Scripts SQL versionados |

## Puesta en marcha (desarrollo)

Requisitos: .NET SDK 10, SQL Server (Express o Developer), Visual Studio 2022 17.14+ o 2026.

1. **Base de datos**: ejecutar en orden los scripts de `Database/` (ver `Database/README.md`).
2. **Secretos** (no van en `appsettings.json`). Desde `ApiCoreCUPPO/ApiCoreCUPPO/ApiCoreCUPPO`:

   ```bash
   dotnet user-secrets set "ConnectionStrings:DefaultConnection" "Server=TU_PC\SQLEXPRESS;Database=CUPPO;Trusted_Connection=True;TrustServerCertificate=True;"
   dotnet user-secrets set "JwtOptions:SecretKey" "una-clave-aleatoria-de-al-menos-32-caracteres"
   ```

   En Visual Studio: clic derecho en el proyecto API → *Manage User Secrets*.
3. **Ejecutar** con el perfil `https` (el predeterminado en Visual Studio): abre Scalar en `https://localhost:7130/scalar/v1`.
   No hay perfil de IIS Express: con él la API no arrancaba en entorno Development y no leía los User Secrets.

**Correo** (recuperación de contraseña): sin la sección `Smtp` configurada, en desarrollo el correo
se escribe en la consola de la API (ahí aparece el código de 6 dígitos). Para enviar correos reales:
`dotnet user-secrets set "Smtp:Host" "smtp.gmail.com"` y lo mismo con `Smtp:User`, `Smtp:Password` y `Smtp:FromAddress`.

> Ejecuta los `dotnet user-secrets` desde la terminal de Visual Studio o una terminal normal de Windows.

## Autenticación

| Endpoint | Uso |
|---|---|
| `POST api/auth/register`, `POST api/auth/login` | Devuelven `token` (JWT, 60 min), `refreshToken` (30 días), `roles` y `permissions` |
| `POST api/auth/refresh` | Cambia el `refreshToken` por una sesión nueva (el anterior deja de servir) |
| `POST api/auth/logout` | Cierra la sesión del dispositivo |
| `POST api/auth/forgot-password`, `POST api/auth/reset-password` | Código de 6 dígitos por correo, vence en 15 min |
| `POST api/users/me/change-password` | Cierra las demás sesiones y devuelve una nueva |

### Otros endpoints

| Endpoint | Acceso | Uso |
|---|---|---|
| `GET api/catalog` | Público | Deportes, superficies, comodidades, métodos de pago, estados, ciudades y zonas |
| `GET api/catalog/exchange-rate` | Público | Tasa BCV vigente |
| `GET api/venues?sportId&cityId&zoneId&search&latitude&longitude&page&pageSize` | Público | Buscar complejos (con ubicación ordena por distancia) |
| `GET api/venues/{id}` | Público | Ficha: fotos, comodidades, canchas con precios, métodos de pago aceptados |
| `GET api/users/me` | Sesión | Perfil, roles y estado de la solicitud de dueño |
| `POST api/owners/me/verification` | Sesión | Solicitar ser dueño (queda pendiente) |
| `GET api/owners/me` | Sesión | Estado de mi solicitud de dueño |
| `GET api/admin/owner-requests?statusId=1` | SUPERADMIN | Solicitudes de dueño |
| `PUT api/admin/owner-requests/{userId}` | SUPERADMIN | Aprobar (2), rechazar (3) o suspender (4) |
| `POST api/admin/exchange-rates` | SUPERADMIN | Registrar la tasa BCV del día |

### Panel de dueño (solo dueños verificados)

| Endpoint | Uso |
|---|---|
| `GET/POST api/owner/venues`, `GET/PUT api/owner/venues/{id}` | Mis complejos (un complejo nuevo queda pendiente de aprobación de CUPPO) |
| `PUT api/owner/venues/{id}/status` · `/amenities` | Pausar/activar · comodidades |
| `POST/PUT api/owner/venues/{id}/payment-accounts[/{accountId}]` | Cuentas de cobro (Pago Móvil, transferencia, Zelle, Binance, efectivo) |
| `POST api/owner/venues/{id}/photos` (multipart `file`) | Fotos (máx. 10; JPG/PNG/WEBP de hasta 5 MB) |
| `GET/POST api/owner/venues/{id}/courts`, `PUT api/owner/courts/{courtId}` | Canchas |
| `PUT api/owner/courts/{courtId}/schedule` | Horario semanal (reemplaza todo) |
| `PUT api/owner/courts/{courtId}/prices` | Tarifas por hora en USD (reemplaza todo) |
| `GET api/owner/venues/{id}/blocks?from&to`, `POST api/owner/courts/{courtId}/blocks`, `DELETE api/owner/blocks/{id}` | Bloqueos (no se permiten sobre reservas activas) |
| `POST api/owners/me/document` (multipart `file`) | Foto de cédula/RIF (privada) |
| `GET/PUT api/admin/venue-requests[/{venueId}]` | SUPERADMIN: aprobar complejos (reciben el plan de prueba) |

Ejemplo de horario: `[{"dayOfWeek":1,"openTime":"08:00","closeTime":"00:00"}]` (1 lunes … 7 domingo; `00:00` = medianoche).
Ejemplo de tarifas: `[{"dayOfWeek":null,"startTime":"08:00","endTime":"18:00","pricePerHourUSD":30}]` (`null` = todos los días).

**Archivos:** se guardan en `storage/` junto a la API (o en `Storage:RootPath`). Las fotos se publican en `/uploads/...`;
los documentos de identidad quedan en `storage/private` y solo se descargan con `GET api/admin/owner-requests/{userId}/document`.

Respuestas de operaciones: `{ code, message, data }`. `code > 0` es éxito; un error de negocio responde 400 con
el mensaje del SP; un error interno responde 500 con un mensaje genérico (el detalle queda en `Log.ErrorLog`).

- La app debe guardar el `refreshToken` en almacenamiento seguro (`SecureStorage` en MAUI) y llamar a
  `refresh` cuando reciba un 401.
- Si se reusa un `refreshToken` ya usado (posible robo), se cierran todas las sesiones del usuario.
- Login, registro y recuperación tienen un límite de 20 peticiones por minuto por IP (responde 429).
- Políticas en controladores: `[Authorize(Policy = Policies.VerifiedOwner)]` y `[Authorize(Policy = Policies.SuperAdmin)]`.

En producción los mismos valores se pasan como variables de entorno:
`ConnectionStrings__DefaultConnection`, `JwtOptions__SecretKey` y `Cors__AllowedOrigins__0`.

## Convenciones

**Flujo por funcionalidad** (de abajo hacia arriba):
tabla → stored procedure → repositorio → servicio → controlador → pantalla MAUI.
Cada funcionalidad se prueba en Scalar antes de pasar a la app.

**Base de datos**
- Un esquema por área: `Security`, `Log`, `Catalog`, `Venue`, `Booking`, `Payment`...
- Tablas en plural y PascalCase (`Security.Users`); PK `<Entidad>ID` con `IDENTITY`.
- Columnas de auditoría: `StatusID`, `CreationUserID`, `CreationDate`, `UpdateUserID`, `UpdateDate`.
- Stored procedures `Verbo + Entidad` (`InsertUser`, `GetUserPermissions`), con salida
  `@CodeResult INT OUTPUT` (> 0 éxito; ≤ 0 error) y `@MessageResult VARCHAR(MAX) OUTPUT`.
- Errores: `TRY/CATCH` + `ROLLBACK` + `EXEC [Log].[InsertLogError]`.
- Todo cambio de BD se guarda como script en `Database/` (nunca solo en SSMS).

**API (C#)**
- Una carpeta por área en cada capa (`DTOs/Security`, `Services/Security`, ...).
- Los controladores no tienen lógica: validan `ModelState` y llaman al servicio.
- El ID del usuario se toma **siempre del token** (`User.GetUserId()`), nunca del body ni de la URL.
- Rutas en minúscula: `api/<recurso>`; lo del usuario autenticado bajo `api/<recurso>/me`.
- Mensajes al usuario en español; código (clases, métodos, columnas) en inglés.

**Git**
- `main` siempre compila. Trabajar en ramas `feature/<nombre>` o `fix/<nombre>` y unir por Pull Request.
- Commits cortos en español, en imperativo: `Agrega SP de disponibilidad de canchas`.
