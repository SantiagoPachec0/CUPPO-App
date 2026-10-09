USE [CUPPO];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================================
   13. STORED PROCEDURES: CATÁLOGOS, TASA BCV Y SOLICITUDES DE DUEÑO (Fase 2)
   ============================================================================ */

-- ===== Catalog.GetCatalogs
-- Todos los catálogos activos en una sola llamada (la app los guarda al iniciar).
-- Result sets: 1 deportes, 2 superficies, 3 comodidades, 4 métodos de pago,
--              5 estados, 6 ciudades, 7 zonas.
CREATE OR ALTER PROCEDURE [Catalog].[GetCatalogs]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [SportID], [Code], [Name], [Icon], [DefaultSlotMinutes]
    FROM [Catalog].[Sports] WHERE [StatusID] = 1 ORDER BY [DisplayOrder], [Name];

    SELECT [SurfaceID], [Code], [Name]
    FROM [Catalog].[Surfaces] WHERE [StatusID] = 1 ORDER BY [Name];

    SELECT [AmenityID], [Code], [Name], [Icon]
    FROM [Catalog].[Amenities] WHERE [StatusID] = 1 ORDER BY [Name];

    SELECT [PaymentMethodID], [Code], [Name], RTRIM([Currency]) AS [Currency], [RequiresReference], [IsOnline]
    FROM [Catalog].[PaymentMethods] WHERE [StatusID] = 1 ORDER BY [DisplayOrder];

    SELECT [StateID], [Name]
    FROM [Catalog].[States] WHERE [StatusID] = 1 ORDER BY [Name];

    SELECT [CityID], [StateID], [Name]
    FROM [Catalog].[Cities] WHERE [StatusID] = 1 ORDER BY [Name];

    SELECT [ZoneID], [CityID], [Name]
    FROM [Catalog].[Zones] WHERE [StatusID] = 1 ORDER BY [Name];
END;
GO

-- ===== Catalog.GetLatestExchangeRate (tasa VES vigente)
CREATE OR ALTER PROCEDURE [Catalog].[GetLatestExchangeRate]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1) [RateDate], RTRIM([Currency]) AS [Currency], [RatePerUSD], [Source]
    FROM [Catalog].[ExchangeRates]
    WHERE [Currency] = 'VES'
    ORDER BY [RateDate] DESC, [ExchangeRateID] DESC;
END;
GO

-- ===== Catalog.UpsertExchangeRate (SUPERADMIN registra la tasa BCV del día)
CREATE OR ALTER PROCEDURE [Catalog].[UpsertExchangeRate]
    @RateDate DATE,
    @RatePerUSD DECIMAL(18,4),
    @Source VARCHAR(20) = 'BCV',
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @RatePerUSD IS NULL OR @RatePerUSD <= 0
    BEGIN
        SET @CodeResult = -2;
        SET @MessageResult = 'La tasa debe ser mayor que cero.';
        RETURN;
    END

    MERGE [Catalog].[ExchangeRates] AS T
    USING (SELECT @RateDate AS [RateDate], 'VES' AS [Currency], ISNULL(@Source, 'BCV') AS [Source]) AS S
    ON T.[RateDate] = S.[RateDate] AND T.[Currency] = S.[Currency] AND T.[Source] = S.[Source]
    WHEN MATCHED THEN UPDATE SET [RatePerUSD] = @RatePerUSD
    WHEN NOT MATCHED THEN INSERT ([RateDate], [Currency], [RatePerUSD], [Source]) VALUES (S.[RateDate], S.[Currency], @RatePerUSD, S.[Source]);

    SET @CodeResult = 1;
    SET @MessageResult = 'Tasa registrada.';
END;
GO

-- ===== Venue.GetOwnerProfile (estado de la solicitud de dueño de un usuario)
CREATE OR ALTER PROCEDURE [Venue].[GetOwnerProfile]
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT OP.[UserID], OP.[DocumentType], OP.[DocumentNumber], OP.[LegalName], OP.[Phone], OP.[DocumentUrl],
           OP.[VerificationStatusID], VS.[Code] AS [VerificationStatusCode], VS.[Name] AS [VerificationStatusName],
           OP.[ReviewNotes], OP.[ReviewedDate], OP.[CreationDate]
    FROM [Venue].[OwnerProfiles] OP
    INNER JOIN [Venue].[VerificationStatuses] VS ON VS.[VerificationStatusID] = OP.[VerificationStatusID]
    WHERE OP.[UserID] = @UserID;
END;
GO

-- ===== Venue.GetOwnerRequests (lista para el administrador)
-- @VerificationStatusID NULL = todas.
CREATE OR ALTER PROCEDURE [Venue].[GetOwnerRequests]
    @VerificationStatusID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT OP.[UserID], U.[UserLogin], U.[Name], U.[Mail],
           OP.[DocumentType], OP.[DocumentNumber], OP.[LegalName], OP.[Phone], OP.[DocumentUrl],
           OP.[VerificationStatusID], VS.[Code] AS [VerificationStatusCode], VS.[Name] AS [VerificationStatusName],
           OP.[ReviewNotes], OP.[ReviewedDate], OP.[CreationDate],
           (SELECT COUNT(*) FROM [Venue].[Venues] V WHERE V.[OwnerUserID] = OP.[UserID]) AS [VenueCount]
    FROM [Venue].[OwnerProfiles] OP
    INNER JOIN [Security].[Users] U ON U.[UserID] = OP.[UserID]
    INNER JOIN [Venue].[VerificationStatuses] VS ON VS.[VerificationStatusID] = OP.[VerificationStatusID]
    WHERE @VerificationStatusID IS NULL OR OP.[VerificationStatusID] = @VerificationStatusID
    ORDER BY CASE WHEN OP.[VerificationStatusID] = 1 THEN 0 ELSE 1 END, ISNULL(OP.[UpdateDate], OP.[CreationDate]);
END;
GO
