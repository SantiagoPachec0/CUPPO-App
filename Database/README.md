# Base de datos CUPPO

Scripts para crear la base desde cero. Ejecutar **en orden**:

| Script | Contenido |
|---|---|
| `00_Database_Schemas.sql` | Crea la base `CUPPO` y los esquemas `Security` y `Log` |
| `01_Tables.sql` | Tablas de seguridad y log |
| `02_Functions.sql` | `Security.encryptHash` (hash SHA2-512 + salt) |
| `03_StoredProcedures.sql` | Stored procedures de seguridad y log |
| `04_SeedData.sql` | Roles, módulos y acciones iniciales |
| `05_Catalog.sql` | Catálogos: estados, deportes, superficies, estados/ciudades/zonas, comodidades, métodos de pago, tasa BCV, parámetros |
| `06_Venue.sql` | Perfiles de dueño, complejos, canchas, fotos, horarios, precios, bloqueos, cuentas de cobro |
| `07_Booking.sql` | Reservas, bloques ocupados e historial de estados |
| `08_Payment_Billing_Social.sql` | Pagos, planes y suscripciones, reseñas, favoritos, notificaciones |
| `09_SeedData_Catalogs.sql` | Datos de catálogos, menú de módulos y permisos por rol |
| `10_SP_Security_Owners.sql` | Registro con rol CLIENT, permisos y verificación de dueños |
| `11_SP_Booking_Payment.sql` | Disponibilidad, reservas, cancelación, jobs, pagos |
| `12_Auth.sql` | Contraseñas BCrypt (migración automática), refresh tokens, códigos de recuperación |
| `13_SP_Catalog_Owners.sql` | Catálogos en una llamada, tasa BCV, consulta de solicitudes de dueño |
| `14_SP_Venue_Management.sql` | Panel de dueño: complejos, canchas, horarios, precios, bloqueos, cuentas de cobro, fotos; revisión de complejos |
| `15_SP_Public_Venues.sql` | Búsqueda pública de complejos (filtros y distancia) y ficha pública |

Los scripts de datos (`04`, `09`) se pueden ejecutar varias veces sin duplicar nada.

Desde la línea de comandos (`-f 65001` para que los acentos se lean bien):

```bash
sqlcmd -S "TU_PC\SQLEXPRESS" -E -C -b -f 65001 -i 00_Database_Schemas.sql,01_Tables.sql,02_Functions.sql,03_StoredProcedures.sql,04_SeedData.sql,05_Catalog.sql,06_Venue.sql,07_Booking.sql,08_Payment_Billing_Social.sql,09_SeedData_Catalogs.sql,10_SP_Security_Owners.sql,11_SP_Booking_Payment.sql,12_Auth.sql,13_SP_Catalog_Owners.sql,14_SP_Venue_Management.sql,15_SP_Public_Venues.sql
```

O abrirlos en SSMS y ejecutarlos uno por uno. Los cambios nuevos se agregan como scripts numerados
a continuación (`12_...sql`), sin editar los anteriores una vez aplicados en otra máquina.

## Solo desarrollo (`dev/`)

| Script | Contenido |
|---|---|
| `dev/01_DemoData.sql` | SUPERADMIN para SPacheco y OAmin; dueño `demo_dueno` / `Demo12345!` ya verificado, con un complejo, 2 canchas, horarios, precios, Pago Móvil y tasa BCV de ejemplo |
| `dev/90_Tests_Phase1.sql` | 29 pruebas de reglas de negocio. **Deja datos**: ejecutar en una base aparte (ej. `CUPPO_Test` creada con los mismos scripts), nunca en `CUPPO` |

## Reglas que viven en la base

**Roles y Panel de dueño**
- Todo usuario nuevo recibe el rol `CLIENT` (ve *Mis reservas*).
- Para ser dueño: `Venue.RequestOwnerVerification` deja la solicitud pendiente;
  un `SUPERADMIN` la revisa con `Venue.ReviewOwnerVerification` (2 aprobar, 3 rechazar, 4 suspender).
- Aprobar asigna `COMPLEX_ADMIN`; rechazar o suspender lo quita. Además, `GetUserPermissions`
  ignora `COMPLEX_ADMIN` si el perfil no está aprobado: el *Panel de dueño* (`MOD_OWNER`) solo
  aparece para dueños verificados.

**Reservas**
- Una reserva ocupa bloques de 30 minutos en `Booking.BookingSlots`; su llave primaria
  `(CourtID, SlotStart)` impide que dos reservas se pisen, incluso si llegan al mismo tiempo.
- Estados: `PENDING_PAYMENT → PAYMENT_REVIEW → CONFIRMED → COMPLETED`, o `CANCELLED` / `EXPIRED` / `NO_SHOW`.
- El jugador tiene `Venues.BookingHoldMinutes` (30 por defecto) para registrar el pago.
- Precio = suma del precio por hora de cada media hora (una reserva puede cruzar de tarifa día a noche).
- Parámetros editables en `Catalog.Settings`: comisión, máximo de reservas sin pagar, días de anticipación, etc.

**Jobs que debe correr la API** (servicio en segundo plano, Fase 3)
- `Booking.ExpirePendingBookings` cada minuto.
- `Booking.CompletePastBookings` cada hora.

## Convenciones

- Horas de cancha y de reservas: **hora local de Venezuela** (`Catalog.GetLocalDateTime()`).
  Fechas de auditoría y `ExpiresAt`: **UTC** (`SYSUTCDATETIME()`).
- `DayOfWeek`: 1 = lunes ... 7 = domingo (`Catalog.GetIsoDayOfWeek`). `CloseTime = '00:00'` significa medianoche.
- Texto escrito por usuarios (nombres de complejos, descripciones, reseñas): `NVARCHAR`. Códigos y referencias: `VARCHAR`.
- Montos en USD con `DECIMAL(10,2)`; los pagos en bolívares guardan la tasa BCV usada.
- Cada script nuevo empieza con `SET ANSI_NULLS ON` y `SET QUOTED_IDENTIFIER ON` (`sqlcmd` los trae apagados
  y sin ellos fallan los índices filtrados).
