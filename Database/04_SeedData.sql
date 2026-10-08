USE [CUPPO];
GO

/* ============================================================================
   DATOS INICIALES DE SEGURIDAD (idempotente: se puede ejecutar varias veces)
   CreationUserID = 1 corresponde al primer usuario (SUPERADMIN).
   ============================================================================ */

-- ===== Security.Roles
SET IDENTITY_INSERT [Security].[Roles] ON;
MERGE [Security].[Roles] AS T
USING (VALUES
    (1, 'SUPERADMIN',    'Super Administrador',       'Acceso total a la plataforma'),
    (2, 'COMPLEX_ADMIN', 'Administrador de Complejo', 'Gestiona canchas, precios y reservas de su sede'),
    (3, 'CLIENT',        'Cliente Final',             'Realiza búsquedas y reservas de canchas')
) AS S ([RoleID], [Code], [Name], [Description])
ON T.[RoleID] = S.[RoleID]
WHEN NOT MATCHED THEN
    INSERT ([RoleID], [Code], [Name], [Description], [StatusID], [CreationUserID])
    VALUES (S.[RoleID], S.[Code], S.[Name], S.[Description], 1, 1);
SET IDENTITY_INSERT [Security].[Roles] OFF;
GO

-- ===== Security.Modules
SET IDENTITY_INSERT [Security].[Modules] ON;
MERGE [Security].[Modules] AS T
USING (VALUES
    (1, 'MOD_COMPLEX',  'Complejos Deportivos', 'Gestión de complejos y sedes',       'building',     '/complexes', 1),
    (2, 'MOD_COURTS',   'Canchas',              'Gestión de canchas y deportes',      'soccer-field', '/courts',    2),
    (3, 'MOD_BOOKINGS', 'Reservas',             'Motor de reservas y calendario',     'calendar',     '/bookings',  3),
    (4, 'MOD_PAYMENTS', 'Pagos',                'Gestión y validación de pagos',      'wallet',       '/payments',  4),
    (5, 'MOD_USERS',    'Usuarios',             'Administración de usuarios y roles', 'users',        '/users',     5)
) AS S ([ModuleID], [Code], [Name], [Description], [Icon], [Route], [DisplayOrder])
ON T.[ModuleID] = S.[ModuleID]
WHEN NOT MATCHED THEN
    INSERT ([ModuleID], [Code], [Name], [Description], [ParentModuleID], [Icon], [Route], [DisplayOrder], [StatusID], [CreationUserID])
    VALUES (S.[ModuleID], S.[Code], S.[Name], S.[Description], NULL, S.[Icon], S.[Route], S.[DisplayOrder], 1, 1);
SET IDENTITY_INSERT [Security].[Modules] OFF;
GO

-- ===== Security.Actions
SET IDENTITY_INSERT [Security].[Actions] ON;
MERGE [Security].[Actions] AS T
USING (VALUES
    (1, 'READ',    'Ver / Consultar',      'Permite la lectura de información'),
    (2, 'CREATE',  'Crear',                'Permite el registro de nuevos datos'),
    (3, 'UPDATE',  'Editar',               'Permite la actualización de información'),
    (4, 'DELETE',  'Eliminar / Inactivar', 'Permite la eliminación de registros'),
    (5, 'APPROVE', 'Aprobar',              'Permite la aprobación de operaciones (ej. Pagos)'),
    (6, 'CANCEL',  'Cancelar',             'Permite la cancelación (ej. Reservas)')
) AS S ([ActionID], [Code], [Name], [Description])
ON T.[ActionID] = S.[ActionID]
WHEN NOT MATCHED THEN
    INSERT ([ActionID], [Code], [Name], [Description], [StatusID], [CreationUserID])
    VALUES (S.[ActionID], S.[Code], S.[Name], S.[Description], 1, 1);
SET IDENTITY_INSERT [Security].[Actions] OFF;
GO
