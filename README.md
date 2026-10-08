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
