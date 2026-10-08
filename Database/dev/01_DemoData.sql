USE [CUPPO];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================================
   DATOS DE DEMO — SOLO DESARROLLO. No ejecutar en producción.

   - Da el rol SUPERADMIN a las cuentas del equipo (SPacheco, OAmin).
   - Crea un dueño de prueba ya verificado y un complejo con dos canchas,
     horarios, precios, cuenta de Pago Móvil y una tasa BCV.

   Cuenta de prueba:  usuario demo_dueno  /  contraseña Demo12345!
   Idempotente: se puede ejecutar varias veces.
   ============================================================================ */

SET NOCOUNT ON;

DECLARE @Code INT, @Msg VARCHAR(MAX);

-- 1. Administradores del equipo
INSERT INTO [Security].[UserRoles] ([UserID], [RoleID], [CreationUserID])
SELECT U.[UserID], R.[RoleID], U.[UserID]
FROM [Security].[Users] U
CROSS JOIN [Security].[Roles] R
WHERE U.[UserLogin] IN ('SPacheco', 'OAmin')
  AND R.[Code] = 'SUPERADMIN'
  AND NOT EXISTS (SELECT 1 FROM [Security].[UserRoles] UR WHERE UR.[UserID] = U.[UserID] AND UR.[RoleID] = R.[RoleID]);

DECLARE @AdminID INT = (SELECT TOP (1) UR.[UserID]
                        FROM [Security].[UserRoles] UR
                        INNER JOIN [Security].[Roles] R ON R.[RoleID] = UR.[RoleID]
                        WHERE R.[Code] = 'SUPERADMIN'
                        ORDER BY UR.[UserID]);

-- 2. Dueño de prueba
IF NOT EXISTS (SELECT 1 FROM [Security].[Users] WHERE [UserLogin] = 'demo_dueno')
    EXEC [Security].[InsertUser] @UserLogin = 'demo_dueno', @Name = 'Dueño Demo', @Mail = 'demo_dueno@cuppo.local',
         @Password = 'Demo12345!', @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;

DECLARE @OwnerID INT = (SELECT [UserID] FROM [Security].[Users] WHERE [UserLogin] = 'demo_dueno');

IF NOT EXISTS (SELECT 1 FROM [Venue].[OwnerProfiles] WHERE [UserID] = @OwnerID)
    EXEC [Venue].[RequestOwnerVerification] @UserID = @OwnerID, @DocumentType = 'J', @DocumentNumber = '500000001',
         @LegalName = N'Complejo Demo C.A.', @Phone = '04120000000',
         @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;

IF EXISTS (SELECT 1 FROM [Venue].[OwnerProfiles] WHERE [UserID] = @OwnerID AND [VerificationStatusID] <> 2)
    EXEC [Venue].[ReviewOwnerVerification] @UserID = @OwnerID, @VerificationStatusID = 2,
         @ReviewNotes = N'Demo', @ReviewerUserID = @AdminID,
         @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;

-- 3. Complejo verificado
IF NOT EXISTS (SELECT 1 FROM [Venue].[Venues] WHERE [Name] = N'Complejo Demo Los Palos Grandes')
    INSERT INTO [Venue].[Venues] ([OwnerUserID], [Name], [Description], [ZoneID], [Address], [Latitude], [Longitude],
                                  [Phone], [WhatsApp], [VerificationStatusID], [CreationUserID])
    SELECT @OwnerID, N'Complejo Demo Los Palos Grandes', N'Canchas de fútbol 5 y pádel para pruebas.',
           Z.[ZoneID], N'Av. Principal de Los Palos Grandes', 10.502100, -66.842800,
           '02120000000', '04120000000', 2, @OwnerID
    FROM [Catalog].[Zones] Z WHERE Z.[Name] = 'Los Palos Grandes';

DECLARE @VenueID INT = (SELECT [VenueID] FROM [Venue].[Venues] WHERE [Name] = N'Complejo Demo Los Palos Grandes');

INSERT INTO [Venue].[VenueAmenities] ([VenueID], [AmenityID])
SELECT @VenueID, A.[AmenityID] FROM [Catalog].[Amenities] A
WHERE A.[Code] IN ('PARKING', 'LIGHTING', 'BATHROOMS', 'CAFETERIA')
  AND NOT EXISTS (SELECT 1 FROM [Venue].[VenueAmenities] VA WHERE VA.[VenueID] = @VenueID AND VA.[AmenityID] = A.[AmenityID]);

IF NOT EXISTS (SELECT 1 FROM [Venue].[VenuePaymentAccounts] WHERE [VenueID] = @VenueID)
    INSERT INTO [Venue].[VenuePaymentAccounts] ([VenueID], [PaymentMethodID], [BankName], [AccountHolder], [DocumentNumber], [Phone], [CreationUserID])
    SELECT @VenueID, [PaymentMethodID], 'Banesco', N'Complejo Demo C.A.', 'J500000001', '04120000000', @OwnerID
    FROM [Catalog].[PaymentMethods] WHERE [Code] = 'PAGO_MOVIL';

-- 4. Canchas
INSERT INTO [Venue].[Courts] ([VenueID], [SportID], [SurfaceID], [Name], [IsCovered], [HasLighting], [PlayersCapacity], [SlotMinutes], [CreationUserID])
SELECT @VenueID, S.[SportID], SU.[SurfaceID], X.[Name], X.[IsCovered], 1, X.[Players], X.[SlotMinutes], @OwnerID
FROM (VALUES (N'Fútbol 5 - Cancha 1', 'FUTBOL', 'SYNTHETIC_GRASS', 0, 10, 60),
             (N'Pádel - Cancha 1',    'PADEL',  'SYNTHETIC_GRASS', 1, 4,  90)) AS X ([Name], [Sport], [Surface], [IsCovered], [Players], [SlotMinutes])
INNER JOIN [Catalog].[Sports] S ON S.[Code] = X.[Sport]
INNER JOIN [Catalog].[Surfaces] SU ON SU.[Code] = X.[Surface]
WHERE NOT EXISTS (SELECT 1 FROM [Venue].[Courts] C WHERE C.[VenueID] = @VenueID AND C.[Name] = X.[Name]);

-- 5. Horario: todos los días de 08:00 a medianoche
INSERT INTO [Venue].[CourtSchedules] ([CourtID], [DayOfWeek], [OpenTime], [CloseTime])
SELECT C.[CourtID], D.[DayOfWeek], '08:00', '00:00'
FROM [Venue].[Courts] C
CROSS JOIN (VALUES (1), (2), (3), (4), (5), (6), (7)) AS D ([DayOfWeek])
WHERE C.[VenueID] = @VenueID
  AND NOT EXISTS (SELECT 1 FROM [Venue].[CourtSchedules] CS WHERE CS.[CourtID] = C.[CourtID] AND CS.[DayOfWeek] = D.[DayOfWeek]);

-- 6. Precios por hora: día $30, noche (desde 18:00) $40, fin de semana noche $45
INSERT INTO [Venue].[CourtPrices] ([CourtID], [DayOfWeek], [StartTime], [EndTime], [PricePerHourUSD])
SELECT C.[CourtID], P.[DayOfWeek], P.[StartTime], P.[EndTime], P.[Price]
FROM [Venue].[Courts] C
CROSS JOIN (VALUES (NULL, CAST('08:00' AS TIME(0)), CAST('18:00' AS TIME(0)), 30.00),
                   (NULL, '18:00', '00:00', 40.00),
                   (6,    '18:00', '00:00', 45.00),
                   (7,    '18:00', '00:00', 45.00)) AS P ([DayOfWeek], [StartTime], [EndTime], [Price])
WHERE C.[VenueID] = @VenueID
  AND NOT EXISTS (SELECT 1 FROM [Venue].[CourtPrices] CP WHERE CP.[CourtID] = C.[CourtID]);

-- 7. Suscripción de prueba y tasa BCV de ejemplo
IF NOT EXISTS (SELECT 1 FROM [Billing].[VenueSubscriptions] WHERE [VenueID] = @VenueID)
    INSERT INTO [Billing].[VenueSubscriptions] ([VenueID], [SubscriptionPlanID], [StartDate], [EndDate], [CreationUserID])
    SELECT @VenueID, [SubscriptionPlanID], CAST(GETDATE() AS DATE), DATEADD(DAY, [DurationDays], CAST(GETDATE() AS DATE)), @AdminID
    FROM [Billing].[SubscriptionPlans] WHERE [Code] = 'TRIAL';

IF NOT EXISTS (SELECT 1 FROM [Catalog].[ExchangeRates] WHERE [RateDate] = CAST(GETDATE() AS DATE) AND [Currency] = 'VES')
    INSERT INTO [Catalog].[ExchangeRates] ([RateDate], [Currency], [RatePerUSD], [Source])
    VALUES (CAST(GETDATE() AS DATE), 'VES', 200.0000, 'DEMO');

PRINT 'Datos de demo listos.';
GO
