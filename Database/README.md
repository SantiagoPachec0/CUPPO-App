# Base de datos CUPPO

Scripts para crear la base desde cero. Ejecutar **en orden**:

| Script | Contenido |
|---|---|
| `00_Database_Schemas.sql` | Crea la base `CUPPO` y los esquemas `Security` y `Log` |
| `01_Tables.sql` | Tablas, llaves, índices y defaults |
| `02_Functions.sql` | `Security.encryptHash` (hash SHA2-512 + salt) |
| `03_StoredProcedures.sql` | Stored procedures de seguridad y log |
| `04_SeedData.sql` | Roles, módulos y acciones iniciales (se puede ejecutar varias veces) |

Desde la línea de comandos (`-f 65001` para que los acentos se lean bien):

```bash
sqlcmd -S "TU_PC\SQLEXPRESS" -E -C -b -f 65001 -i 00_Database_Schemas.sql,01_Tables.sql,02_Functions.sql,03_StoredProcedures.sql,04_SeedData.sql
```

O abrirlos en SSMS y ejecutarlos uno por uno.

Los scripts `00`–`04` son la línea base exportada el 2026-10-08. Los cambios nuevos se agregan
como scripts numerados a continuación (`05_...sql`, `06_...sql`), sin editar los anteriores.
