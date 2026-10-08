USE [CUPPO];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================================
   09. DATOS INICIALES DE LA FASE 1 (idempotente: se puede ejecutar varias veces)
   ============================================================================ */

SET NOCOUNT ON;
GO

-- ===== Estados genéricos
MERGE [Catalog].[Statuses] AS T
USING (VALUES (1, 'ACTIVE', 'Activo'), (2, 'INACTIVE', 'Inactivo'), (3, 'DELETED', 'Eliminado'))
    AS S ([StatusID], [Code], [Name])
ON T.[StatusID] = S.[StatusID]
WHEN NOT MATCHED THEN INSERT ([StatusID], [Code], [Name]) VALUES (S.[StatusID], S.[Code], S.[Name]);
GO

-- ===== Estados de verificación (dueños y complejos)
MERGE [Venue].[VerificationStatuses] AS T
USING (VALUES (1, 'PENDING',   'Pendiente de revisión'),
              (2, 'APPROVED',  'Verificado'),
              (3, 'REJECTED',  'Rechazado'),
              (4, 'SUSPENDED', 'Suspendido'))
    AS S ([VerificationStatusID], [Code], [Name])
ON T.[VerificationStatusID] = S.[VerificationStatusID]
WHEN NOT MATCHED THEN INSERT ([VerificationStatusID], [Code], [Name]) VALUES (S.[VerificationStatusID], S.[Code], S.[Name]);
GO

-- ===== Estados de reserva
MERGE [Booking].[BookingStatuses] AS T
USING (VALUES (1, 'PENDING_PAYMENT', 'Pendiente de pago',  1),
              (2, 'PAYMENT_REVIEW',  'Pago por verificar', 1),
              (3, 'CONFIRMED',       'Confirmada',         1),
              (4, 'COMPLETED',       'Completada',         1),
              (5, 'CANCELLED',       'Cancelada',          0),
              (6, 'EXPIRED',         'Vencida',            0),
              (7, 'NO_SHOW',         'No asistió',         1))
    AS S ([BookingStatusID], [Code], [Name], [HoldsSlot])
ON T.[BookingStatusID] = S.[BookingStatusID]
WHEN NOT MATCHED THEN INSERT ([BookingStatusID], [Code], [Name], [HoldsSlot]) VALUES (S.[BookingStatusID], S.[Code], S.[Name], S.[HoldsSlot]);
GO

-- ===== Estados de pago
MERGE [Payment].[PaymentStatuses] AS T
USING (VALUES (1, 'PENDING_REVIEW', 'Por verificar'), (2, 'APPROVED', 'Aprobado'), (3, 'REJECTED', 'Rechazado'))
    AS S ([PaymentStatusID], [Code], [Name])
ON T.[PaymentStatusID] = S.[PaymentStatusID]
WHEN NOT MATCHED THEN INSERT ([PaymentStatusID], [Code], [Name]) VALUES (S.[PaymentStatusID], S.[Code], S.[Name]);
GO

-- ===== Deportes
MERGE [Catalog].[Sports] AS T
USING (VALUES ('FUTBOL',      'Fútbol',      'soccer',     60, 1),
              ('PADEL',       'Pádel',       'padel',      90, 2),
              ('TENIS',       'Tenis',       'tennis',     60, 3),
              ('BASQUET',     'Básquet',     'basketball', 60, 4),
              ('VOLEIBOL',    'Vóleibol',    'volleyball', 60, 5),
              ('VOLEY_PLAYA', 'Vóley playa', 'volleyball', 60, 6),
              ('PICKLEBALL',  'Pickleball',  'pickleball', 60, 7),
              ('BEISBOL',     'Béisbol',     'baseball',  120, 8),
              ('SOFTBOL',     'Softbol',     'baseball',  120, 9))
    AS S ([Code], [Name], [Icon], [DefaultSlotMinutes], [DisplayOrder])
ON T.[Code] = S.[Code]
WHEN NOT MATCHED THEN INSERT ([Code], [Name], [Icon], [DefaultSlotMinutes], [DisplayOrder])
    VALUES (S.[Code], S.[Name], S.[Icon], S.[DefaultSlotMinutes], S.[DisplayOrder]);
GO

-- ===== Superficies
MERGE [Catalog].[Surfaces] AS T
USING (VALUES ('NATURAL_GRASS',   'Grama natural'),
              ('SYNTHETIC_GRASS', 'Grama sintética'),
              ('CONCRETE',        'Cemento'),
              ('CLAY',            'Arcilla'),
              ('ACRYLIC',         'Pista dura (acrílico)'),
              ('WOOD',            'Parquet (madera)'),
              ('RUBBER',          'Goma / caucho'),
              ('SAND',            'Arena'))
    AS S ([Code], [Name])
ON T.[Code] = S.[Code]
WHEN NOT MATCHED THEN INSERT ([Code], [Name]) VALUES (S.[Code], S.[Name]);
GO

-- ===== Comodidades
MERGE [Catalog].[Amenities] AS T
USING (VALUES ('PARKING',     'Estacionamiento',          'car'),
              ('LIGHTING',    'Iluminación nocturna',     'lightbulb'),
              ('LOCKER_ROOM', 'Vestuarios',               'shirt'),
              ('SHOWERS',     'Duchas',                   'shower'),
              ('BATHROOMS',   'Baños',                    'toilet'),
              ('CAFETERIA',   'Cafetería / kiosko',       'coffee'),
              ('EQUIPMENT',   'Alquiler de equipos',      'ball'),
              ('SECURITY',    'Vigilancia',               'shield'),
              ('BLEACHERS',   'Gradas',                   'users'),
              ('WIFI',        'Wi-Fi',                    'wifi'))
    AS S ([Code], [Name], [Icon])
ON T.[Code] = S.[Code]
WHEN NOT MATCHED THEN INSERT ([Code], [Name], [Icon]) VALUES (S.[Code], S.[Name], S.[Icon]);
GO

-- ===== Métodos de pago
MERGE [Catalog].[PaymentMethods] AS T
USING (VALUES ('PAGO_MOVIL',   'Pago Móvil',                'VES',  1, 1, 1),
              ('TRANSFER_VES', 'Transferencia en bolívares','VES',  1, 1, 2),
              ('ZELLE',        'Zelle',                     'USD',  1, 1, 3),
              ('BINANCE',      'Binance Pay (USDT)',        'USDT', 1, 1, 4),
              ('CASH_USD',     'Efectivo en dólares',       'USD',  0, 0, 5),
              ('CASH_VES',     'Efectivo en bolívares',     'VES',  0, 0, 6))
    AS S ([Code], [Name], [Currency], [RequiresReference], [IsOnline], [DisplayOrder])
ON T.[Code] = S.[Code]
WHEN NOT MATCHED THEN INSERT ([Code], [Name], [Currency], [RequiresReference], [IsOnline], [DisplayOrder])
    VALUES (S.[Code], S.[Name], S.[Currency], S.[RequiresReference], S.[IsOnline], S.[DisplayOrder]);
GO

-- ===== Parámetros del sistema
MERGE [Catalog].[Settings] AS T
USING (VALUES ('BOOKING_FEE_USD',            '0.00', 'Comisión CUPPO por reserva, en USD'),
              ('MAX_PENDING_BOOKINGS',       '2',    'Máximo de reservas sin pagar por jugador'),
              ('MAX_DAYS_AHEAD',             '30',   'Días hacia adelante en los que se puede reservar'),
              ('MIN_MINUTES_BEFORE_START',   '30',   'Minutos mínimos de anticipación para reservar'),
              ('MAX_BOOKING_MINUTES',        '240',  'Duración máxima de una reserva en minutos'))
    AS S ([SettingKey], [SettingValue], [Description])
ON T.[SettingKey] = S.[SettingKey]
WHEN NOT MATCHED THEN INSERT ([SettingKey], [SettingValue], [Description]) VALUES (S.[SettingKey], S.[SettingValue], S.[Description]);
GO

-- ===== Plan de prueba (los planes pagos se agregan cuando se definan los precios)
MERGE [Billing].[SubscriptionPlans] AS T
USING (VALUES ('TRIAL', 'Prueba gratis', N'Primer mes sin costo para complejos nuevos', 0.00, 30, NULL, 1))
    AS S ([Code], [Name], [Description], [MonthlyPriceUSD], [DurationDays], [MaxCourts], [IsTrial])
ON T.[Code] = S.[Code]
WHEN NOT MATCHED THEN INSERT ([Code], [Name], [Description], [MonthlyPriceUSD], [DurationDays], [MaxCourts], [IsTrial])
    VALUES (S.[Code], S.[Name], S.[Description], S.[MonthlyPriceUSD], S.[DurationDays], S.[MaxCourts], S.[IsTrial]);
GO

-- ===== Estados de Venezuela
MERGE [Catalog].[States] AS T
USING (VALUES ('Amazonas'), ('Anzoátegui'), ('Apure'), ('Aragua'), ('Barinas'), ('Bolívar'),
              ('Carabobo'), ('Cojedes'), ('Delta Amacuro'), ('Distrito Capital'), ('Falcón'),
              ('Guárico'), ('La Guaira'), ('Lara'), ('Mérida'), ('Miranda'), ('Monagas'),
              ('Nueva Esparta'), ('Portuguesa'), ('Sucre'), ('Táchira'), ('Trujillo'),
              ('Yaracuy'), ('Zulia'))
    AS S ([Name])
ON T.[Name] = S.[Name]
WHEN NOT MATCHED THEN INSERT ([Name]) VALUES (S.[Name]);
GO

-- ===== Ciudades / municipios de la Gran Caracas (piloto)
MERGE [Catalog].[Cities] AS T
USING (
    SELECT ST.[StateID], C.[Name]
    FROM (VALUES ('Distrito Capital', 'Caracas - Libertador'),
                 ('Miranda',          'Caracas - Chacao'),
                 ('Miranda',          'Caracas - Baruta'),
                 ('Miranda',          'Caracas - Sucre'),
                 ('Miranda',          'Caracas - El Hatillo')) AS C ([StateName], [Name])
    INNER JOIN [Catalog].[States] ST ON ST.[Name] = C.[StateName]
) AS S ([StateID], [Name])
ON T.[StateID] = S.[StateID] AND T.[Name] = S.[Name]
WHEN NOT MATCHED THEN INSERT ([StateID], [Name]) VALUES (S.[StateID], S.[Name]);
GO

-- ===== Zonas / urbanizaciones del piloto
MERGE [Catalog].[Zones] AS T
USING (
    SELECT CI.[CityID], Z.[Name]
    FROM (VALUES ('Caracas - Libertador', 'Los Chaguaramos'), ('Caracas - Libertador', 'Santa Mónica'),
                 ('Caracas - Libertador', 'El Paraíso'),      ('Caracas - Libertador', 'Montalbán'),
                 ('Caracas - Libertador', 'San Bernardino'),  ('Caracas - Libertador', 'La Candelaria'),
                 ('Caracas - Libertador', 'El Valle'),        ('Caracas - Libertador', 'Catia'),
                 ('Caracas - Chacao',     'Altamira'),        ('Caracas - Chacao',     'Los Palos Grandes'),
                 ('Caracas - Chacao',     'La Castellana'),   ('Caracas - Chacao',     'El Rosal'),
                 ('Caracas - Chacao',     'Campo Alegre'),    ('Caracas - Chacao',     'Chacao'),
                 ('Caracas - Baruta',     'Las Mercedes'),    ('Caracas - Baruta',     'Santa Fe'),
                 ('Caracas - Baruta',     'Prados del Este'), ('Caracas - Baruta',     'La Trinidad'),
                 ('Caracas - Baruta',     'El Cafetal'),      ('Caracas - Baruta',     'Los Samanes'),
                 ('Caracas - Baruta',     'Colinas de Bello Monte'), ('Caracas - Baruta', 'Santa Rosa de Lima'),
                 ('Caracas - Sucre',      'Los Ruices'),      ('Caracas - Sucre',      'La California'),
                 ('Caracas - Sucre',      'Los Dos Caminos'), ('Caracas - Sucre',      'Boleíta'),
                 ('Caracas - Sucre',      'Macaracuay'),      ('Caracas - Sucre',      'Petare'),
                 ('Caracas - El Hatillo', 'La Lagunita'),     ('Caracas - El Hatillo', 'La Boyera'),
                 ('Caracas - El Hatillo', 'Alto Hatillo'),    ('Caracas - El Hatillo', 'El Hatillo')) AS Z ([CityName], [Name])
    INNER JOIN [Catalog].[Cities] CI ON CI.[Name] = Z.[CityName]
) AS S ([CityID], [Name])
ON T.[CityID] = S.[CityID] AND T.[Name] = S.[Name]
WHEN NOT MATCHED THEN INSERT ([CityID], [Name]) VALUES (S.[CityID], S.[Name]);
GO

/* ============================================================================
   MÓDULOS Y PERMISOS
   Menú de la app:
     MOD_BOOKINGS  Mis reservas               → CLIENT (todo jugador)
     MOD_OWNER     Panel de dueño             → COMPLEX_ADMIN (solo dueños verificados)
       ├ MOD_COMPLEX   Mis complejos
       ├ MOD_COURTS    Canchas, horarios y precios
       ├ MOD_AGENDA    Agenda y bloqueos
       └ MOD_PAYMENTS  Verificación de pagos
     MOD_ADMIN     Administración CUPPO       → SUPERADMIN
       ├ MOD_USERS     Usuarios y roles
       └ MOD_VERIFY    Verificación de dueños y complejos
   ============================================================================ */

-- Módulos nuevos (los 5 primeros vienen de 04_SeedData.sql)
MERGE [Security].[Modules] AS T
USING (VALUES ('MOD_OWNER',  'Panel de dueño',          'Herramientas para dueños de complejos verificados', 'store',        '/owner',          10),
              ('MOD_AGENDA', 'Agenda',                  'Agenda del complejo y bloqueos de horario',         'calendar-days','/owner/agenda',   13),
              ('MOD_ADMIN',  'Administración CUPPO',    'Herramientas internas de CUPPO',                    'settings',     '/admin',          20),
              ('MOD_VERIFY', 'Verificaciones',          'Aprobación de dueños y complejos',                  'badge-check',  '/admin/verify',   22))
    AS S ([Code], [Name], [Description], [Icon], [Route], [DisplayOrder])
ON T.[Code] = S.[Code]
WHEN NOT MATCHED THEN INSERT ([Code], [Name], [Description], [Icon], [Route], [DisplayOrder], [StatusID], [CreationUserID])
    VALUES (S.[Code], S.[Name], S.[Description], S.[Icon], S.[Route], S.[DisplayOrder], 1, 1);
GO

-- Jerarquía, rutas y orden del menú
UPDATE M
SET M.[ParentModuleID] = P.[ModuleID],
    M.[Name]           = X.[Name],
    M.[Route]          = X.[Route],
    M.[DisplayOrder]   = X.[DisplayOrder],
    M.[UpdateDate]     = GETDATE()
FROM [Security].[Modules] M
INNER JOIN (VALUES ('MOD_COMPLEX',  'MOD_OWNER', 'Mis complejos',        '/owner/venues',   11),
                   ('MOD_COURTS',   'MOD_OWNER', 'Canchas y precios',    '/owner/courts',   12),
                   ('MOD_AGENDA',   'MOD_OWNER', 'Agenda',               '/owner/agenda',   13),
                   ('MOD_PAYMENTS', 'MOD_OWNER', 'Pagos por verificar',  '/owner/payments', 14),
                   ('MOD_USERS',    'MOD_ADMIN', 'Usuarios',             '/admin/users',    21),
                   ('MOD_VERIFY',   'MOD_ADMIN', 'Verificaciones',       '/admin/verify',   22))
    AS X ([Code], [ParentCode], [Name], [Route], [DisplayOrder]) ON X.[Code] = M.[Code]
INNER JOIN [Security].[Modules] P ON P.[Code] = X.[ParentCode]
WHERE ISNULL(M.[ParentModuleID], 0) <> P.[ModuleID];

UPDATE [Security].[Modules]
SET [Name] = 'Mis reservas', [DisplayOrder] = 1, [UpdateDate] = GETDATE()
WHERE [Code] = 'MOD_BOOKINGS' AND [Name] <> 'Mis reservas';
GO

-- Acciones disponibles en cada módulo
INSERT INTO [Security].[ModuleActions] ([ModuleID], [ActionID], [StatusID])
SELECT M.[ModuleID], A.[ActionID], 1
FROM (VALUES ('MOD_BOOKINGS', 'READ'), ('MOD_BOOKINGS', 'CREATE'), ('MOD_BOOKINGS', 'CANCEL'),
             ('MOD_OWNER',    'READ'),
             ('MOD_COMPLEX',  'READ'), ('MOD_COMPLEX',  'CREATE'), ('MOD_COMPLEX', 'UPDATE'), ('MOD_COMPLEX', 'DELETE'),
             ('MOD_COURTS',   'READ'), ('MOD_COURTS',   'CREATE'), ('MOD_COURTS',  'UPDATE'), ('MOD_COURTS',  'DELETE'),
             ('MOD_AGENDA',   'READ'), ('MOD_AGENDA',   'CREATE'), ('MOD_AGENDA',  'CANCEL'),
             ('MOD_PAYMENTS', 'READ'), ('MOD_PAYMENTS', 'APPROVE'),
             ('MOD_ADMIN',    'READ'),
             ('MOD_USERS',    'READ'), ('MOD_USERS',    'UPDATE'), ('MOD_USERS',   'DELETE'),
             ('MOD_VERIFY',   'READ'), ('MOD_VERIFY',   'APPROVE')) AS X ([ModuleCode], [ActionCode])
INNER JOIN [Security].[Modules] M ON M.[Code] = X.[ModuleCode]
INNER JOIN [Security].[Actions] A ON A.[Code] = X.[ActionCode]
WHERE NOT EXISTS (SELECT 1 FROM [Security].[ModuleActions] MA WHERE MA.[ModuleID] = M.[ModuleID] AND MA.[ActionID] = A.[ActionID]);
GO

-- Permisos por rol
INSERT INTO [Security].[RolePermissions] ([RoleID], [ModuleActionID], [CreationUserID])
SELECT R.[RoleID], MA.[ModuleActionID], 1
FROM [Security].[Roles] R
INNER JOIN [Security].[ModuleActions] MA ON 1 = 1
INNER JOIN [Security].[Modules] M ON M.[ModuleID] = MA.[ModuleID]
WHERE (   (R.[Code] = 'SUPERADMIN')
       OR (R.[Code] = 'CLIENT'        AND M.[Code] = 'MOD_BOOKINGS')
       OR (R.[Code] = 'COMPLEX_ADMIN' AND M.[Code] IN ('MOD_OWNER', 'MOD_COMPLEX', 'MOD_COURTS', 'MOD_AGENDA', 'MOD_PAYMENTS')))
  AND NOT EXISTS (SELECT 1 FROM [Security].[RolePermissions] RP WHERE RP.[RoleID] = R.[RoleID] AND RP.[ModuleActionID] = MA.[ModuleActionID]);
GO

-- Todo usuario existente sin rol pasa a ser CLIENT
INSERT INTO [Security].[UserRoles] ([UserID], [RoleID], [CreationUserID])
SELECT U.[UserID], R.[RoleID], U.[UserID]
FROM [Security].[Users] U
CROSS JOIN [Security].[Roles] R
WHERE R.[Code] = 'CLIENT'
  AND NOT EXISTS (SELECT 1 FROM [Security].[UserRoles] UR WHERE UR.[UserID] = U.[UserID]);
GO
