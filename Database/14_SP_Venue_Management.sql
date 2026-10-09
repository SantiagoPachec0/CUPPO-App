USE [CUPPO];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================================
   14. PANEL DE DUEÑO: COMPLEJOS, CANCHAS, HORARIOS, PRECIOS, BLOQUEOS,
       CUENTAS DE COBRO Y FOTOS (Fase 2)

   Todos los SP de escritura validan que @UserID sea el dueño VERIFICADO del
   complejo (Venue.CanManageVenue / Venue.CanManageCourt). Si no, devuelven
   CodeResult = -403.

   Horarios y precios se reciben como JSON y reemplazan la configuración
   completa de la cancha:
     horario: [{"dayOfWeek":1,"openTime":"08:00","closeTime":"00:00"}, ...]
     precios: [{"dayOfWeek":null,"startTime":"08:00","endTime":"18:00","pricePerHourUSD":30}, ...]
   ============================================================================ */

-- ===== Notas de revisión del complejo (motivo de rechazo o suspensión)
IF COL_LENGTH('Venue.Venues', 'VerificationNotes') IS NULL
    ALTER TABLE [Venue].[Venues] ADD [VerificationNotes] NVARCHAR(500) NULL;
GO

-- ===== Permisos
CREATE OR ALTER FUNCTION [Venue].[CanManageVenue](@UserID INT, @VenueID INT)
RETURNS BIT
AS
BEGIN
    RETURN CASE WHEN EXISTS (
        SELECT 1
        FROM [Venue].[Venues] V
        INNER JOIN [Venue].[OwnerProfiles] OP ON OP.[UserID] = V.[OwnerUserID]
        WHERE V.[VenueID] = @VenueID
          AND V.[OwnerUserID] = @UserID
          AND V.[StatusID] <> 3
          AND OP.[VerificationStatusID] = 2
    ) THEN 1 ELSE 0 END;
END;
GO

CREATE OR ALTER FUNCTION [Venue].[CanManageCourt](@UserID INT, @CourtID INT)
RETURNS BIT
AS
BEGIN
    DECLARE @VenueID INT = (SELECT [VenueID] FROM [Venue].[Courts] WHERE [CourtID] = @CourtID AND [StatusID] <> 3);
    RETURN CASE WHEN @VenueID IS NULL THEN 0 ELSE [Venue].[CanManageVenue](@UserID, @VenueID) END;
END;
GO

-- ===== Minutos desde medianoche; '00:00' como hora de cierre vale 1440 (fin del día)
CREATE OR ALTER FUNCTION [Venue].[TimeToMinutes](@Time TIME(0), @IsEnd BIT)
RETURNS INT
AS
BEGIN
    DECLARE @Minutes INT = DATEPART(HOUR, @Time) * 60 + DATEPART(MINUTE, @Time);
    RETURN CASE WHEN @IsEnd = 1 AND @Minutes = 0 THEN 1440 ELSE @Minutes END;
END;
GO

/* ============================================================================
   COMPLEJOS
   ============================================================================ */

-- ===== Venue.InsertVenue: lo crea un dueño verificado; queda pendiente de aprobación de CUPPO
CREATE OR ALTER PROCEDURE [Venue].[InsertVenue]
    @UserID INT,
    @Name NVARCHAR(100),
    @Description NVARCHAR(1000) = NULL,
    @ZoneID INT,
    @Address NVARCHAR(250),
    @Latitude DECIMAL(9,6) = NULL,
    @Longitude DECIMAL(9,6) = NULL,
    @Phone VARCHAR(20) = NULL,
    @WhatsApp VARCHAR(20) = NULL,
    @Instagram VARCHAR(50) = NULL,
    @BookingHoldMinutes INT = 30,
    @CancellationHours INT = 24,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM [Venue].[OwnerProfiles] WHERE [UserID] = @UserID AND [VerificationStatusID] = 2)
        BEGIN
            SET @CodeResult = -403;
            SET @MessageResult = 'Solo un dueño verificado puede registrar complejos.';
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM [Catalog].[Zones] WHERE [ZoneID] = @ZoneID AND [StatusID] = 1)
        BEGIN
            SET @CodeResult = -2;
            SET @MessageResult = 'La zona indicada no existe.';
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM [Venue].[Venues] WHERE [OwnerUserID] = @UserID AND [Name] = @Name AND [StatusID] <> 3)
        BEGIN
            SET @CodeResult = -3;
            SET @MessageResult = 'Ya tienes un complejo con ese nombre.';
            RETURN;
        END

        INSERT INTO [Venue].[Venues] (
            [OwnerUserID], [Name], [Description], [ZoneID], [Address], [Latitude], [Longitude],
            [Phone], [WhatsApp], [Instagram], [BookingHoldMinutes], [CancellationHours],
            [VerificationStatusID], [StatusID], [CreationUserID]
        )
        VALUES (
            @UserID, @Name, @Description, @ZoneID, @Address, @Latitude, @Longitude,
            @Phone, @WhatsApp, @Instagram, ISNULL(@BookingHoldMinutes, 30), ISNULL(@CancellationHours, 24),
            1, 1, @UserID
        );

        SET @CodeResult = SCOPE_IDENTITY();
        SET @MessageResult = 'Complejo registrado. CUPPO lo revisará antes de publicarlo.';
    END TRY
    BEGIN CATCH
        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();
        DECLARE @InputData VARCHAR(MAX) = CONCAT('Name: ', @Name, ' | ZoneID: ', @ZoneID);
        EXECUTE [Log].[InsertLogError] @UserId = @UserID, @AppModule = 'Venue', @MethodName = NULL,
            @ProcedureName = '[Venue].[InsertVenue]', @ErrorCode = @CodeResult, @ErrorMessage = @MessageResult,
            @InputData = @InputData, @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Venue.UpdateVenue: reemplaza los datos del complejo
CREATE OR ALTER PROCEDURE [Venue].[UpdateVenue]
    @VenueID INT,
    @UserID INT,
    @Name NVARCHAR(100),
    @Description NVARCHAR(1000) = NULL,
    @ZoneID INT,
    @Address NVARCHAR(250),
    @Latitude DECIMAL(9,6) = NULL,
    @Longitude DECIMAL(9,6) = NULL,
    @Phone VARCHAR(20) = NULL,
    @WhatsApp VARCHAR(20) = NULL,
    @Instagram VARCHAR(50) = NULL,
    @BookingHoldMinutes INT = 30,
    @CancellationHours INT = 24,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF [Venue].[CanManageVenue](@UserID, @VenueID) = 0
        BEGIN
            SET @CodeResult = -403;
            SET @MessageResult = 'No tienes permiso sobre este complejo.';
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM [Catalog].[Zones] WHERE [ZoneID] = @ZoneID AND [StatusID] = 1)
        BEGIN
            SET @CodeResult = -2;
            SET @MessageResult = 'La zona indicada no existe.';
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM [Venue].[Venues] WHERE [OwnerUserID] = @UserID AND [Name] = @Name AND [VenueID] <> @VenueID AND [StatusID] <> 3)
        BEGIN
            SET @CodeResult = -3;
            SET @MessageResult = 'Ya tienes otro complejo con ese nombre.';
            RETURN;
        END

        UPDATE [Venue].[Venues]
        SET [Name] = @Name, [Description] = @Description, [ZoneID] = @ZoneID, [Address] = @Address,
            [Latitude] = @Latitude, [Longitude] = @Longitude, [Phone] = @Phone, [WhatsApp] = @WhatsApp,
            [Instagram] = @Instagram,
            [BookingHoldMinutes] = ISNULL(@BookingHoldMinutes, [BookingHoldMinutes]),
            [CancellationHours] = ISNULL(@CancellationHours, [CancellationHours]),
            [UpdateUserID] = @UserID, [UpdateDate] = SYSUTCDATETIME()
        WHERE [VenueID] = @VenueID;

        SET @CodeResult = @VenueID;
        SET @MessageResult = 'Complejo actualizado.';
    END TRY
    BEGIN CATCH
        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();
        DECLARE @InputData VARCHAR(MAX) = CONCAT('VenueID: ', @VenueID);
        EXECUTE [Log].[InsertLogError] @UserId = @UserID, @AppModule = 'Venue', @MethodName = NULL,
            @ProcedureName = '[Venue].[UpdateVenue]', @ErrorCode = @CodeResult, @ErrorMessage = @MessageResult,
            @InputData = @InputData, @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Venue.SetVenueStatus: 1 activo (visible), 2 pausado (oculto, no recibe reservas)
CREATE OR ALTER PROCEDURE [Venue].[SetVenueStatus]
    @VenueID INT,
    @UserID INT,
    @StatusID INT,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF [Venue].[CanManageVenue](@UserID, @VenueID) = 0
    BEGIN
        SET @CodeResult = -403;
        SET @MessageResult = 'No tienes permiso sobre este complejo.';
        RETURN;
    END

    IF @StatusID NOT IN (1, 2)
    BEGIN
        SET @CodeResult = -2;
        SET @MessageResult = 'Estado inválido: 1 activo, 2 pausado.';
        RETURN;
    END

    UPDATE [Venue].[Venues]
    SET [StatusID] = @StatusID, [UpdateUserID] = @UserID, [UpdateDate] = SYSUTCDATETIME()
    WHERE [VenueID] = @VenueID;

    SET @CodeResult = @VenueID;
    SET @MessageResult = CASE @StatusID WHEN 1 THEN 'Complejo activado.' ELSE 'Complejo pausado: no aparecerá en búsquedas ni recibirá reservas.' END;
END;
GO

-- ===== Venue.SetVenueAmenities: reemplaza las comodidades (@AmenityIDs = '1,3,5')
CREATE OR ALTER PROCEDURE [Venue].[SetVenueAmenities]
    @VenueID INT,
    @UserID INT,
    @AmenityIDs VARCHAR(500) = NULL,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF [Venue].[CanManageVenue](@UserID, @VenueID) = 0
    BEGIN
        SET @CodeResult = -403;
        SET @MessageResult = 'No tienes permiso sobre este complejo.';
        RETURN;
    END

    DECLARE @Ids TABLE ([AmenityID] INT PRIMARY KEY);
    INSERT INTO @Ids ([AmenityID])
    SELECT DISTINCT TRY_CAST(LTRIM(RTRIM([value])) AS INT)
    FROM STRING_SPLIT(ISNULL(@AmenityIDs, ''), ',')
    WHERE TRY_CAST(LTRIM(RTRIM([value])) AS INT) IS NOT NULL;

    IF EXISTS (SELECT 1 FROM @Ids I WHERE NOT EXISTS (SELECT 1 FROM [Catalog].[Amenities] A WHERE A.[AmenityID] = I.[AmenityID] AND A.[StatusID] = 1))
    BEGIN
        SET @CodeResult = -2;
        SET @MessageResult = 'Alguna de las comodidades indicadas no existe.';
        RETURN;
    END

    BEGIN TRANSACTION;
        DELETE FROM [Venue].[VenueAmenities] WHERE [VenueID] = @VenueID;
        INSERT INTO [Venue].[VenueAmenities] ([VenueID], [AmenityID]) SELECT @VenueID, [AmenityID] FROM @Ids;
    COMMIT TRANSACTION;

    SET @CodeResult = @VenueID;
    SET @MessageResult = 'Comodidades actualizadas.';
END;
GO

-- ===== Venue.GetOwnerVenues: complejos del dueño
CREATE OR ALTER PROCEDURE [Venue].[GetOwnerVenues]
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT V.[VenueID], V.[Name], V.[Address], Z.[Name] AS [ZoneName], CI.[Name] AS [CityName],
           V.[VerificationStatusID], VS.[Code] AS [VerificationStatusCode], VS.[Name] AS [VerificationStatusName],
           V.[VerificationNotes], V.[StatusID],
           (SELECT COUNT(*) FROM [Venue].[Courts] C WHERE C.[VenueID] = V.[VenueID] AND C.[StatusID] <> 3) AS [CourtCount],
           (SELECT TOP (1) P.[Url] FROM [Venue].[VenuePhotos] P WHERE P.[VenueID] = V.[VenueID] ORDER BY P.[IsCover] DESC, P.[DisplayOrder]) AS [CoverUrl]
    FROM [Venue].[Venues] V
    INNER JOIN [Catalog].[Zones] Z ON Z.[ZoneID] = V.[ZoneID]
    INNER JOIN [Catalog].[Cities] CI ON CI.[CityID] = Z.[CityID]
    INNER JOIN [Venue].[VerificationStatuses] VS ON VS.[VerificationStatusID] = V.[VerificationStatusID]
    WHERE V.[OwnerUserID] = @UserID AND V.[StatusID] <> 3
    ORDER BY V.[Name];
END;
GO

-- ===== Venue.GetVenueForOwner: ficha completa para editar
-- Result sets: 1 complejo, 2 fotos, 3 comodidades, 4 cuentas de cobro.
-- Si @UserID no puede administrarlo, no devuelve filas.
CREATE OR ALTER PROCEDURE [Venue].[GetVenueForOwner]
    @VenueID INT,
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Allowed BIT = [Venue].[CanManageVenue](@UserID, @VenueID);

    SELECT V.[VenueID], V.[Name], V.[Description], V.[ZoneID], Z.[Name] AS [ZoneName], Z.[CityID], CI.[Name] AS [CityName],
           V.[Address], V.[Latitude], V.[Longitude], V.[Phone], V.[WhatsApp], V.[Instagram],
           V.[BookingHoldMinutes], V.[CancellationHours],
           V.[VerificationStatusID], VS.[Code] AS [VerificationStatusCode], VS.[Name] AS [VerificationStatusName],
           V.[VerificationNotes], V.[StatusID]
    FROM [Venue].[Venues] V
    INNER JOIN [Catalog].[Zones] Z ON Z.[ZoneID] = V.[ZoneID]
    INNER JOIN [Catalog].[Cities] CI ON CI.[CityID] = Z.[CityID]
    INNER JOIN [Venue].[VerificationStatuses] VS ON VS.[VerificationStatusID] = V.[VerificationStatusID]
    WHERE V.[VenueID] = @VenueID AND @Allowed = 1;

    SELECT [VenuePhotoID], [Url], [IsCover], [DisplayOrder]
    FROM [Venue].[VenuePhotos]
    WHERE [VenueID] = @VenueID AND @Allowed = 1
    ORDER BY [IsCover] DESC, [DisplayOrder], [VenuePhotoID];

    SELECT A.[AmenityID], A.[Code], A.[Name], A.[Icon]
    FROM [Venue].[VenueAmenities] VA
    INNER JOIN [Catalog].[Amenities] A ON A.[AmenityID] = VA.[AmenityID]
    WHERE VA.[VenueID] = @VenueID AND @Allowed = 1
    ORDER BY A.[Name];

    SELECT VPA.[VenuePaymentAccountID], VPA.[PaymentMethodID], PM.[Code] AS [PaymentMethodCode], PM.[Name] AS [PaymentMethodName],
           RTRIM(PM.[Currency]) AS [Currency], VPA.[BankName], VPA.[AccountHolder], VPA.[DocumentNumber], VPA.[Phone],
           VPA.[AccountNumber], VPA.[Email], VPA.[Notes], VPA.[StatusID]
    FROM [Venue].[VenuePaymentAccounts] VPA
    INNER JOIN [Catalog].[PaymentMethods] PM ON PM.[PaymentMethodID] = VPA.[PaymentMethodID]
    WHERE VPA.[VenueID] = @VenueID AND VPA.[StatusID] <> 3 AND @Allowed = 1
    ORDER BY PM.[DisplayOrder];
END;
GO

/* ============================================================================
   CUENTAS DE COBRO
   ============================================================================ */

-- ===== Venue.UpsertVenuePaymentAccount: @VenuePaymentAccountID NULL = nueva
-- Datos obligatorios según el método:
--   PAGO_MOVIL: banco, cédula/RIF y teléfono · TRANSFER_VES: banco, titular, cédula/RIF y número de cuenta
--   ZELLE: titular y correo · BINANCE: correo · efectivo: ninguno
CREATE OR ALTER PROCEDURE [Venue].[UpsertVenuePaymentAccount]
    @VenuePaymentAccountID INT = NULL,
    @VenueID INT,
    @UserID INT,
    @PaymentMethodID INT,
    @BankName VARCHAR(80) = NULL,
    @AccountHolder NVARCHAR(150) = NULL,
    @DocumentNumber VARCHAR(20) = NULL,
    @Phone VARCHAR(20) = NULL,
    @AccountNumber VARCHAR(30) = NULL,
    @Email VARCHAR(100) = NULL,
    @Notes NVARCHAR(250) = NULL,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF [Venue].[CanManageVenue](@UserID, @VenueID) = 0
        BEGIN
            SET @CodeResult = -403;
            SET @MessageResult = 'No tienes permiso sobre este complejo.';
            RETURN;
        END

        IF @VenuePaymentAccountID IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM [Venue].[VenuePaymentAccounts] WHERE [VenuePaymentAccountID] = @VenuePaymentAccountID AND [VenueID] = @VenueID AND [StatusID] <> 3)
        BEGIN
            SET @CodeResult = -2;
            SET @MessageResult = 'La cuenta de cobro no existe.';
            RETURN;
        END

        DECLARE @MethodCode VARCHAR(20) = (SELECT [Code] FROM [Catalog].[PaymentMethods] WHERE [PaymentMethodID] = @PaymentMethodID AND [StatusID] = 1);
        IF @MethodCode IS NULL
        BEGIN
            SET @CodeResult = -3;
            SET @MessageResult = 'Método de pago no válido.';
            RETURN;
        END

        DECLARE @Missing VARCHAR(200) =
            CASE @MethodCode
                WHEN 'PAGO_MOVIL'   THEN CASE WHEN NULLIF(@BankName, '') IS NULL OR NULLIF(@DocumentNumber, '') IS NULL OR NULLIF(@Phone, '') IS NULL
                                              THEN 'Pago Móvil requiere banco, cédula/RIF y teléfono.' END
                WHEN 'TRANSFER_VES' THEN CASE WHEN NULLIF(@BankName, '') IS NULL OR NULLIF(@AccountHolder, N'') IS NULL OR NULLIF(@DocumentNumber, '') IS NULL OR NULLIF(@AccountNumber, '') IS NULL
                                              THEN 'La transferencia requiere banco, titular, cédula/RIF y número de cuenta.' END
                WHEN 'ZELLE'        THEN CASE WHEN NULLIF(@AccountHolder, N'') IS NULL OR NULLIF(@Email, '') IS NULL
                                              THEN 'Zelle requiere titular y correo.' END
                WHEN 'BINANCE'      THEN CASE WHEN NULLIF(@Email, '') IS NULL
                                              THEN 'Binance Pay requiere el correo o ID de la cuenta.' END
            END;

        IF @Missing IS NOT NULL
        BEGIN
            SET @CodeResult = -4;
            SET @MessageResult = @Missing;
            RETURN;
        END

        IF @VenuePaymentAccountID IS NULL
        BEGIN
            INSERT INTO [Venue].[VenuePaymentAccounts] (
                [VenueID], [PaymentMethodID], [BankName], [AccountHolder], [DocumentNumber], [Phone],
                [AccountNumber], [Email], [Notes], [StatusID], [CreationUserID]
            )
            VALUES (@VenueID, @PaymentMethodID, @BankName, @AccountHolder, @DocumentNumber, @Phone,
                    @AccountNumber, @Email, @Notes, 1, @UserID);

            SET @CodeResult = SCOPE_IDENTITY();
            SET @MessageResult = 'Cuenta de cobro agregada.';
        END
        ELSE
        BEGIN
            UPDATE [Venue].[VenuePaymentAccounts]
            SET [PaymentMethodID] = @PaymentMethodID, [BankName] = @BankName, [AccountHolder] = @AccountHolder,
                [DocumentNumber] = @DocumentNumber, [Phone] = @Phone, [AccountNumber] = @AccountNumber,
                [Email] = @Email, [Notes] = @Notes, [UpdateUserID] = @UserID, [UpdateDate] = SYSUTCDATETIME()
            WHERE [VenuePaymentAccountID] = @VenuePaymentAccountID;

            SET @CodeResult = @VenuePaymentAccountID;
            SET @MessageResult = 'Cuenta de cobro actualizada.';
        END
    END TRY
    BEGIN CATCH
        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();
        DECLARE @InputData VARCHAR(MAX) = CONCAT('VenueID: ', @VenueID, ' | PaymentMethodID: ', @PaymentMethodID);
        EXECUTE [Log].[InsertLogError] @UserId = @UserID, @AppModule = 'Venue', @MethodName = NULL,
            @ProcedureName = '[Venue].[UpsertVenuePaymentAccount]', @ErrorCode = @CodeResult, @ErrorMessage = @MessageResult,
            @InputData = @InputData, @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Venue.SetVenuePaymentAccountStatus: 1 activa, 2 inactiva, 3 eliminada
CREATE OR ALTER PROCEDURE [Venue].[SetVenuePaymentAccountStatus]
    @VenuePaymentAccountID INT,
    @UserID INT,
    @StatusID INT,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @VenueID INT = (SELECT [VenueID] FROM [Venue].[VenuePaymentAccounts] WHERE [VenuePaymentAccountID] = @VenuePaymentAccountID AND [StatusID] <> 3);

    IF @VenueID IS NULL OR [Venue].[CanManageVenue](@UserID, @VenueID) = 0
    BEGIN
        SET @CodeResult = -403;
        SET @MessageResult = 'No tienes permiso sobre esta cuenta de cobro.';
        RETURN;
    END

    IF @StatusID NOT IN (1, 2, 3)
    BEGIN
        SET @CodeResult = -2;
        SET @MessageResult = 'Estado inválido: 1 activa, 2 inactiva, 3 eliminada.';
        RETURN;
    END

    UPDATE [Venue].[VenuePaymentAccounts]
    SET [StatusID] = @StatusID, [UpdateUserID] = @UserID, [UpdateDate] = SYSUTCDATETIME()
    WHERE [VenuePaymentAccountID] = @VenuePaymentAccountID;

    SET @CodeResult = @VenuePaymentAccountID;
    SET @MessageResult = 'Cuenta de cobro actualizada.';
END;
GO

/* ============================================================================
   CANCHAS
   ============================================================================ */

-- ===== Venue.UpsertCourt: @CourtID NULL = nueva cancha en @VenueID
CREATE OR ALTER PROCEDURE [Venue].[UpsertCourt]
    @CourtID INT = NULL,
    @VenueID INT = NULL,
    @UserID INT,
    @SportID INT,
    @SurfaceID INT = NULL,
    @Name NVARCHAR(80),
    @Description NVARCHAR(500) = NULL,
    @IsCovered BIT = 0,
    @HasLighting BIT = 0,
    @PlayersCapacity INT = NULL,
    @SlotMinutes INT = 60,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @CourtID IS NOT NULL
            SET @VenueID = (SELECT [VenueID] FROM [Venue].[Courts] WHERE [CourtID] = @CourtID AND [StatusID] <> 3);

        IF @VenueID IS NULL OR [Venue].[CanManageVenue](@UserID, @VenueID) = 0
        BEGIN
            SET @CodeResult = -403;
            SET @MessageResult = 'No tienes permiso sobre esta cancha o complejo.';
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM [Catalog].[Sports] WHERE [SportID] = @SportID AND [StatusID] = 1)
           OR (@SurfaceID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Catalog].[Surfaces] WHERE [SurfaceID] = @SurfaceID AND [StatusID] = 1))
        BEGIN
            SET @CodeResult = -2;
            SET @MessageResult = 'Deporte o superficie no válidos.';
            RETURN;
        END

        IF @SlotMinutes IS NULL OR @SlotMinutes < 30 OR @SlotMinutes > 240 OR @SlotMinutes % 30 <> 0
        BEGIN
            SET @CodeResult = -3;
            SET @MessageResult = 'La duración del turno debe ser de 30 a 240 minutos, en bloques de 30.';
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM [Venue].[Courts] WHERE [VenueID] = @VenueID AND [Name] = @Name AND [StatusID] <> 3
                   AND (@CourtID IS NULL OR [CourtID] <> @CourtID))
        BEGIN
            SET @CodeResult = -4;
            SET @MessageResult = 'Ya existe una cancha con ese nombre en el complejo.';
            RETURN;
        END

        IF @CourtID IS NULL
        BEGIN
            INSERT INTO [Venue].[Courts] (
                [VenueID], [SportID], [SurfaceID], [Name], [Description], [IsCovered], [HasLighting],
                [PlayersCapacity], [SlotMinutes], [StatusID], [CreationUserID]
            )
            VALUES (@VenueID, @SportID, @SurfaceID, @Name, @Description, ISNULL(@IsCovered, 0), ISNULL(@HasLighting, 0),
                    @PlayersCapacity, @SlotMinutes, 1, @UserID);

            SET @CodeResult = SCOPE_IDENTITY();
            SET @MessageResult = 'Cancha creada. Configura su horario y precios para recibir reservas.';
        END
        ELSE
        BEGIN
            UPDATE [Venue].[Courts]
            SET [SportID] = @SportID, [SurfaceID] = @SurfaceID, [Name] = @Name, [Description] = @Description,
                [IsCovered] = ISNULL(@IsCovered, 0), [HasLighting] = ISNULL(@HasLighting, 0),
                [PlayersCapacity] = @PlayersCapacity, [SlotMinutes] = @SlotMinutes,
                [UpdateUserID] = @UserID, [UpdateDate] = SYSUTCDATETIME()
            WHERE [CourtID] = @CourtID;

            SET @CodeResult = @CourtID;
            SET @MessageResult = 'Cancha actualizada.';
        END
    END TRY
    BEGIN CATCH
        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();
        DECLARE @InputData VARCHAR(MAX) = CONCAT('CourtID: ', @CourtID, ' | VenueID: ', @VenueID);
        EXECUTE [Log].[InsertLogError] @UserId = @UserID, @AppModule = 'Venue', @MethodName = NULL,
            @ProcedureName = '[Venue].[UpsertCourt]', @ErrorCode = @CodeResult, @ErrorMessage = @MessageResult,
            @InputData = @InputData, @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Venue.SetCourtStatus: 1 activa, 2 inactiva, 3 eliminada
-- No se puede inactivar ni eliminar una cancha con reservas futuras activas.
CREATE OR ALTER PROCEDURE [Venue].[SetCourtStatus]
    @CourtID INT,
    @UserID INT,
    @StatusID INT,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF [Venue].[CanManageCourt](@UserID, @CourtID) = 0
    BEGIN
        SET @CodeResult = -403;
        SET @MessageResult = 'No tienes permiso sobre esta cancha.';
        RETURN;
    END

    IF @StatusID NOT IN (1, 2, 3)
    BEGIN
        SET @CodeResult = -2;
        SET @MessageResult = 'Estado inválido: 1 activa, 2 inactiva, 3 eliminada.';
        RETURN;
    END

    IF @StatusID <> 1 AND EXISTS (
        SELECT 1 FROM [Booking].[Bookings]
        WHERE [CourtID] = @CourtID AND [BookingStatusID] IN (1, 2, 3) AND [EndDateTime] > [Catalog].[GetLocalDateTime]())
    BEGIN
        SET @CodeResult = -3;
        SET @MessageResult = 'La cancha tiene reservas futuras. Cancélalas antes de desactivarla.';
        RETURN;
    END

    UPDATE [Venue].[Courts]
    SET [StatusID] = @StatusID, [UpdateUserID] = @UserID, [UpdateDate] = SYSUTCDATETIME()
    WHERE [CourtID] = @CourtID;

    SET @CodeResult = @CourtID;
    SET @MessageResult = 'Estado de la cancha actualizado.';
END;
GO

-- ===== Venue.SetCourtSchedule: reemplaza el horario semanal completo
CREATE OR ALTER PROCEDURE [Venue].[SetCourtSchedule]
    @CourtID INT,
    @UserID INT,
    @ScheduleJson NVARCHAR(MAX),
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF [Venue].[CanManageCourt](@UserID, @CourtID) = 0
        BEGIN
            SET @CodeResult = -403;
            SET @MessageResult = 'No tienes permiso sobre esta cancha.';
            RETURN;
        END

        IF ISJSON(@ScheduleJson) = 0
        BEGIN
            SET @CodeResult = -2;
            SET @MessageResult = 'Formato de horario inválido.';
            RETURN;
        END

        DECLARE @S TABLE ([RowID] INT IDENTITY(1,1), [DayOfWeek] INT, [OpenTime] TIME(0), [CloseTime] TIME(0));
        INSERT INTO @S ([DayOfWeek], [OpenTime], [CloseTime])
        SELECT [DayOfWeek], TRY_CAST([OpenTime] AS TIME(0)), TRY_CAST([CloseTime] AS TIME(0))
        FROM OPENJSON(@ScheduleJson)
        WITH ([DayOfWeek] INT '$.dayOfWeek', [OpenTime] VARCHAR(8) '$.openTime', [CloseTime] VARCHAR(8) '$.closeTime');

        IF EXISTS (SELECT 1 FROM @S WHERE [DayOfWeek] NOT BETWEEN 1 AND 7 OR [DayOfWeek] IS NULL OR [OpenTime] IS NULL OR [CloseTime] IS NULL)
        BEGIN
            SET @CodeResult = -3;
            SET @MessageResult = 'Cada franja necesita día (1 lunes a 7 domingo), hora de apertura y de cierre (HH:mm).';
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM @S WHERE DATEPART(MINUTE, [OpenTime]) NOT IN (0, 30) OR DATEPART(MINUTE, [CloseTime]) NOT IN (0, 30))
        BEGIN
            SET @CodeResult = -4;
            SET @MessageResult = 'Las horas deben ser en punto o y media.';
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM @S WHERE [Venue].[TimeToMinutes]([CloseTime], 1) <= [Venue].[TimeToMinutes]([OpenTime], 0))
        BEGIN
            SET @CodeResult = -5;
            SET @MessageResult = 'La hora de cierre debe ser posterior a la de apertura (00:00 = medianoche).';
            RETURN;
        END

        IF EXISTS (
            SELECT 1 FROM @S A INNER JOIN @S B ON A.[DayOfWeek] = B.[DayOfWeek] AND A.[RowID] < B.[RowID]
            WHERE [Venue].[TimeToMinutes](A.[OpenTime], 0) < [Venue].[TimeToMinutes](B.[CloseTime], 1)
              AND [Venue].[TimeToMinutes](B.[OpenTime], 0) < [Venue].[TimeToMinutes](A.[CloseTime], 1))
        BEGIN
            SET @CodeResult = -6;
            SET @MessageResult = 'Hay franjas que se pisan el mismo día.';
            RETURN;
        END

        BEGIN TRANSACTION;
            DELETE FROM [Venue].[CourtSchedules] WHERE [CourtID] = @CourtID;
            INSERT INTO [Venue].[CourtSchedules] ([CourtID], [DayOfWeek], [OpenTime], [CloseTime])
            SELECT @CourtID, [DayOfWeek], [OpenTime], [CloseTime] FROM @S;
        COMMIT TRANSACTION;

        SET @CodeResult = @CourtID;
        SET @MessageResult = 'Horario actualizado. Las reservas ya hechas no cambian.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();
        DECLARE @InputData VARCHAR(MAX) = CONCAT('CourtID: ', @CourtID);
        EXECUTE [Log].[InsertLogError] @UserId = @UserID, @AppModule = 'Venue', @MethodName = NULL,
            @ProcedureName = '[Venue].[SetCourtSchedule]', @ErrorCode = @CodeResult, @ErrorMessage = @MessageResult,
            @InputData = @InputData, @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Venue.SetCourtPrices: reemplaza las tarifas de la cancha
-- dayOfWeek null = todos los días; una franja de un día específico tiene prioridad.
CREATE OR ALTER PROCEDURE [Venue].[SetCourtPrices]
    @CourtID INT,
    @UserID INT,
    @PricesJson NVARCHAR(MAX),
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF [Venue].[CanManageCourt](@UserID, @CourtID) = 0
        BEGIN
            SET @CodeResult = -403;
            SET @MessageResult = 'No tienes permiso sobre esta cancha.';
            RETURN;
        END

        IF ISJSON(@PricesJson) = 0
        BEGIN
            SET @CodeResult = -2;
            SET @MessageResult = 'Formato de precios inválido.';
            RETURN;
        END

        DECLARE @P TABLE ([RowID] INT IDENTITY(1,1), [DayOfWeek] INT NULL, [StartTime] TIME(0), [EndTime] TIME(0), [Price] DECIMAL(10,2));
        INSERT INTO @P ([DayOfWeek], [StartTime], [EndTime], [Price])
        SELECT [DayOfWeek], TRY_CAST([StartTime] AS TIME(0)), TRY_CAST([EndTime] AS TIME(0)), [Price]
        FROM OPENJSON(@PricesJson)
        WITH ([DayOfWeek] INT '$.dayOfWeek', [StartTime] VARCHAR(8) '$.startTime', [EndTime] VARCHAR(8) '$.endTime',
              [Price] DECIMAL(10,2) '$.pricePerHourUSD');

        IF EXISTS (SELECT 1 FROM @P WHERE ([DayOfWeek] IS NOT NULL AND [DayOfWeek] NOT BETWEEN 1 AND 7)
                                       OR [StartTime] IS NULL OR [EndTime] IS NULL OR [Price] IS NULL OR [Price] < 0)
        BEGIN
            SET @CodeResult = -3;
            SET @MessageResult = 'Cada tarifa necesita hora de inicio, hora de fin (HH:mm) y precio por hora mayor o igual a 0.';
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM @P WHERE DATEPART(MINUTE, [StartTime]) NOT IN (0, 30) OR DATEPART(MINUTE, [EndTime]) NOT IN (0, 30))
        BEGIN
            SET @CodeResult = -4;
            SET @MessageResult = 'Las horas deben ser en punto o y media.';
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM @P WHERE [Venue].[TimeToMinutes]([EndTime], 1) <= [Venue].[TimeToMinutes]([StartTime], 0))
        BEGIN
            SET @CodeResult = -5;
            SET @MessageResult = 'La hora de fin debe ser posterior a la de inicio (00:00 = medianoche).';
            RETURN;
        END

        IF EXISTS (
            SELECT 1 FROM @P A INNER JOIN @P B ON ISNULL(A.[DayOfWeek], 0) = ISNULL(B.[DayOfWeek], 0) AND A.[RowID] < B.[RowID]
            WHERE [Venue].[TimeToMinutes](A.[StartTime], 0) < [Venue].[TimeToMinutes](B.[EndTime], 1)
              AND [Venue].[TimeToMinutes](B.[StartTime], 0) < [Venue].[TimeToMinutes](A.[EndTime], 1))
        BEGIN
            SET @CodeResult = -6;
            SET @MessageResult = 'Hay tarifas que se pisan para el mismo día.';
            RETURN;
        END

        BEGIN TRANSACTION;
            DELETE FROM [Venue].[CourtPrices] WHERE [CourtID] = @CourtID;
            INSERT INTO [Venue].[CourtPrices] ([CourtID], [DayOfWeek], [StartTime], [EndTime], [PricePerHourUSD])
            SELECT @CourtID, [DayOfWeek], [StartTime], [EndTime], [Price] FROM @P;
        COMMIT TRANSACTION;

        SET @CodeResult = @CourtID;
        SET @MessageResult = 'Precios actualizados. Las reservas ya hechas mantienen su precio.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();
        DECLARE @InputData VARCHAR(MAX) = CONCAT('CourtID: ', @CourtID);
        EXECUTE [Log].[InsertLogError] @UserId = @UserID, @AppModule = 'Venue', @MethodName = NULL,
            @ProcedureName = '[Venue].[SetCourtPrices]', @ErrorCode = @CodeResult, @ErrorMessage = @MessageResult,
            @InputData = @InputData, @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Venue.GetCourtsForOwner: canchas de un complejo con su configuración
-- Result sets: 1 canchas, 2 horarios, 3 precios, 4 fotos.
CREATE OR ALTER PROCEDURE [Venue].[GetCourtsForOwner]
    @VenueID INT,
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Allowed BIT = [Venue].[CanManageVenue](@UserID, @VenueID);

    SELECT C.[CourtID], C.[VenueID], C.[SportID], S.[Name] AS [SportName], C.[SurfaceID], SU.[Name] AS [SurfaceName],
           C.[Name], C.[Description], C.[IsCovered], C.[HasLighting], C.[PlayersCapacity], C.[SlotMinutes], C.[StatusID]
    FROM [Venue].[Courts] C
    INNER JOIN [Catalog].[Sports] S ON S.[SportID] = C.[SportID]
    LEFT JOIN [Catalog].[Surfaces] SU ON SU.[SurfaceID] = C.[SurfaceID]
    WHERE C.[VenueID] = @VenueID AND C.[StatusID] <> 3 AND @Allowed = 1
    ORDER BY C.[Name];

    SELECT CS.[CourtID], CAST(CS.[DayOfWeek] AS INT) AS [DayOfWeek], CONVERT(VARCHAR(5), CS.[OpenTime], 108) AS [OpenTime], CONVERT(VARCHAR(5), CS.[CloseTime], 108) AS [CloseTime]
    FROM [Venue].[CourtSchedules] CS
    INNER JOIN [Venue].[Courts] C ON C.[CourtID] = CS.[CourtID]
    WHERE C.[VenueID] = @VenueID AND C.[StatusID] <> 3 AND CS.[StatusID] = 1 AND @Allowed = 1
    ORDER BY CS.[CourtID], CS.[DayOfWeek], CS.[OpenTime];

    SELECT CP.[CourtID], CAST(CP.[DayOfWeek] AS INT) AS [DayOfWeek], CONVERT(VARCHAR(5), CP.[StartTime], 108) AS [StartTime], CONVERT(VARCHAR(5), CP.[EndTime], 108) AS [EndTime],
           CP.[PricePerHourUSD]
    FROM [Venue].[CourtPrices] CP
    INNER JOIN [Venue].[Courts] C ON C.[CourtID] = CP.[CourtID]
    WHERE C.[VenueID] = @VenueID AND C.[StatusID] <> 3 AND CP.[StatusID] = 1 AND @Allowed = 1
    ORDER BY CP.[CourtID], ISNULL(CP.[DayOfWeek], 0), CP.[StartTime];

    SELECT CPH.[CourtPhotoID], CPH.[CourtID], CPH.[Url], CPH.[DisplayOrder]
    FROM [Venue].[CourtPhotos] CPH
    INNER JOIN [Venue].[Courts] C ON C.[CourtID] = CPH.[CourtID]
    WHERE C.[VenueID] = @VenueID AND C.[StatusID] <> 3 AND @Allowed = 1
    ORDER BY CPH.[CourtID], CPH.[DisplayOrder], CPH.[CourtPhotoID];
END;
GO

/* ============================================================================
   BLOQUEOS DE HORARIO
   ============================================================================ */

-- ===== Venue.InsertCourtBlock: no se permite sobre reservas activas
CREATE OR ALTER PROCEDURE [Venue].[InsertCourtBlock]
    @CourtID INT,
    @UserID INT,
    @StartDateTime DATETIME2(0),
    @EndDateTime DATETIME2(0),
    @Reason NVARCHAR(250) = NULL,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF [Venue].[CanManageCourt](@UserID, @CourtID) = 0
    BEGIN
        SET @CodeResult = -403;
        SET @MessageResult = 'No tienes permiso sobre esta cancha.';
        RETURN;
    END

    IF @EndDateTime <= @StartDateTime OR DATEDIFF(DAY, @StartDateTime, @EndDateTime) > 90
    BEGIN
        SET @CodeResult = -2;
        SET @MessageResult = 'Rango inválido: el fin debe ser posterior al inicio y el bloqueo de máximo 90 días.';
        RETURN;
    END

    IF @EndDateTime <= [Catalog].[GetLocalDateTime]()
    BEGIN
        SET @CodeResult = -3;
        SET @MessageResult = 'No se pueden bloquear horarios que ya pasaron.';
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM [Booking].[BookingSlots]
               WHERE [CourtID] = @CourtID AND [SlotStart] < @EndDateTime AND DATEADD(MINUTE, 30, [SlotStart]) > @StartDateTime)
    BEGIN
        SET @CodeResult = -4;
        SET @MessageResult = 'Hay reservas activas en ese horario. Cancélalas antes de bloquearlo.';
        RETURN;
    END

    INSERT INTO [Venue].[CourtBlocks] ([CourtID], [StartDateTime], [EndDateTime], [Reason], [CreationUserID])
    VALUES (@CourtID, @StartDateTime, @EndDateTime, @Reason, @UserID);

    SET @CodeResult = SCOPE_IDENTITY();
    SET @MessageResult = 'Horario bloqueado.';
END;
GO

CREATE OR ALTER PROCEDURE [Venue].[DeleteCourtBlock]
    @CourtBlockID INT,
    @UserID INT,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CourtID INT = (SELECT [CourtID] FROM [Venue].[CourtBlocks] WHERE [CourtBlockID] = @CourtBlockID);

    IF @CourtID IS NULL OR [Venue].[CanManageCourt](@UserID, @CourtID) = 0
    BEGIN
        SET @CodeResult = -403;
        SET @MessageResult = 'No tienes permiso sobre este bloqueo.';
        RETURN;
    END

    DELETE FROM [Venue].[CourtBlocks] WHERE [CourtBlockID] = @CourtBlockID;

    SET @CodeResult = @CourtBlockID;
    SET @MessageResult = 'Bloqueo eliminado.';
END;
GO

-- ===== Venue.GetCourtBlocks: bloqueos del complejo entre dos fechas
CREATE OR ALTER PROCEDURE [Venue].[GetCourtBlocks]
    @VenueID INT,
    @UserID INT,
    @From DATETIME2(0),
    @To DATETIME2(0)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CB.[CourtBlockID], CB.[CourtID], C.[Name] AS [CourtName], CB.[StartDateTime], CB.[EndDateTime], CB.[Reason]
    FROM [Venue].[CourtBlocks] CB
    INNER JOIN [Venue].[Courts] C ON C.[CourtID] = CB.[CourtID]
    WHERE C.[VenueID] = @VenueID
      AND CB.[StartDateTime] < @To AND CB.[EndDateTime] > @From
      AND [Venue].[CanManageVenue](@UserID, @VenueID) = 1
    ORDER BY CB.[StartDateTime];
END;
GO

/* ============================================================================
   FOTOS
   ============================================================================ */

-- ===== Venue.InsertVenuePhoto (máximo 10). La primera foto queda como portada.
CREATE OR ALTER PROCEDURE [Venue].[InsertVenuePhoto]
    @VenueID INT,
    @UserID INT,
    @Url VARCHAR(500),
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF [Venue].[CanManageVenue](@UserID, @VenueID) = 0
    BEGIN
        SET @CodeResult = -403;
        SET @MessageResult = 'No tienes permiso sobre este complejo.';
        RETURN;
    END

    DECLARE @Count INT = (SELECT COUNT(*) FROM [Venue].[VenuePhotos] WHERE [VenueID] = @VenueID);
    IF @Count >= 10
    BEGIN
        SET @CodeResult = -2;
        SET @MessageResult = 'El complejo ya tiene 10 fotos. Elimina alguna para subir otra.';
        RETURN;
    END

    INSERT INTO [Venue].[VenuePhotos] ([VenueID], [Url], [IsCover], [DisplayOrder])
    VALUES (@VenueID, @Url, CASE WHEN @Count = 0 THEN 1 ELSE 0 END, @Count + 1);

    SET @CodeResult = SCOPE_IDENTITY();
    SET @MessageResult = 'Foto agregada.';
END;
GO

-- ===== Venue.DeleteVenuePhoto: devuelve la URL en @DeletedUrl para borrar el archivo
CREATE OR ALTER PROCEDURE [Venue].[DeleteVenuePhoto]
    @VenuePhotoID INT,
    @UserID INT,
    @DeletedUrl VARCHAR(500) OUTPUT,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @VenueID INT, @WasCover BIT;
    SELECT @VenueID = [VenueID], @DeletedUrl = [Url], @WasCover = [IsCover]
    FROM [Venue].[VenuePhotos] WHERE [VenuePhotoID] = @VenuePhotoID;

    IF @VenueID IS NULL OR [Venue].[CanManageVenue](@UserID, @VenueID) = 0
    BEGIN
        SET @DeletedUrl = NULL;
        SET @CodeResult = -403;
        SET @MessageResult = 'No tienes permiso sobre esta foto.';
        RETURN;
    END

    BEGIN TRANSACTION;
        DELETE FROM [Venue].[VenuePhotos] WHERE [VenuePhotoID] = @VenuePhotoID;

        -- Si era la portada, la siguiente foto pasa a serlo
        IF @WasCover = 1
            UPDATE [Venue].[VenuePhotos] SET [IsCover] = 1
            WHERE [VenuePhotoID] = (SELECT TOP (1) [VenuePhotoID] FROM [Venue].[VenuePhotos] WHERE [VenueID] = @VenueID ORDER BY [DisplayOrder], [VenuePhotoID]);
    COMMIT TRANSACTION;

    SET @CodeResult = @VenuePhotoID;
    SET @MessageResult = 'Foto eliminada.';
END;
GO

CREATE OR ALTER PROCEDURE [Venue].[SetVenueCoverPhoto]
    @VenuePhotoID INT,
    @UserID INT,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @VenueID INT = (SELECT [VenueID] FROM [Venue].[VenuePhotos] WHERE [VenuePhotoID] = @VenuePhotoID);

    IF @VenueID IS NULL OR [Venue].[CanManageVenue](@UserID, @VenueID) = 0
    BEGIN
        SET @CodeResult = -403;
        SET @MessageResult = 'No tienes permiso sobre esta foto.';
        RETURN;
    END

    BEGIN TRANSACTION;
        UPDATE [Venue].[VenuePhotos] SET [IsCover] = 0 WHERE [VenueID] = @VenueID AND [IsCover] = 1;
        UPDATE [Venue].[VenuePhotos] SET [IsCover] = 1 WHERE [VenuePhotoID] = @VenuePhotoID;
    COMMIT TRANSACTION;

    SET @CodeResult = @VenuePhotoID;
    SET @MessageResult = 'Portada actualizada.';
END;
GO

-- ===== Venue.InsertCourtPhoto (máximo 5 por cancha)
CREATE OR ALTER PROCEDURE [Venue].[InsertCourtPhoto]
    @CourtID INT,
    @UserID INT,
    @Url VARCHAR(500),
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF [Venue].[CanManageCourt](@UserID, @CourtID) = 0
    BEGIN
        SET @CodeResult = -403;
        SET @MessageResult = 'No tienes permiso sobre esta cancha.';
        RETURN;
    END

    DECLARE @Count INT = (SELECT COUNT(*) FROM [Venue].[CourtPhotos] WHERE [CourtID] = @CourtID);
    IF @Count >= 5
    BEGIN
        SET @CodeResult = -2;
        SET @MessageResult = 'La cancha ya tiene 5 fotos. Elimina alguna para subir otra.';
        RETURN;
    END

    INSERT INTO [Venue].[CourtPhotos] ([CourtID], [Url], [DisplayOrder]) VALUES (@CourtID, @Url, @Count + 1);

    SET @CodeResult = SCOPE_IDENTITY();
    SET @MessageResult = 'Foto agregada.';
END;
GO

CREATE OR ALTER PROCEDURE [Venue].[DeleteCourtPhoto]
    @CourtPhotoID INT,
    @UserID INT,
    @DeletedUrl VARCHAR(500) OUTPUT,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CourtID INT;
    SELECT @CourtID = [CourtID], @DeletedUrl = [Url] FROM [Venue].[CourtPhotos] WHERE [CourtPhotoID] = @CourtPhotoID;

    IF @CourtID IS NULL OR [Venue].[CanManageCourt](@UserID, @CourtID) = 0
    BEGIN
        SET @DeletedUrl = NULL;
        SET @CodeResult = -403;
        SET @MessageResult = 'No tienes permiso sobre esta foto.';
        RETURN;
    END

    DELETE FROM [Venue].[CourtPhotos] WHERE [CourtPhotoID] = @CourtPhotoID;

    SET @CodeResult = @CourtPhotoID;
    SET @MessageResult = 'Foto eliminada.';
END;
GO

-- ===== Venue.SetOwnerDocument: foto de cédula/RIF (solo mientras la solicitud está pendiente o rechazada)
CREATE OR ALTER PROCEDURE [Venue].[SetOwnerDocument]
    @UserID INT,
    @DocumentUrl VARCHAR(500),
    @PreviousUrl VARCHAR(500) OUTPUT,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StatusID INT;
    SELECT @StatusID = [VerificationStatusID], @PreviousUrl = [DocumentUrl]
    FROM [Venue].[OwnerProfiles] WHERE [UserID] = @UserID;

    IF @StatusID IS NULL
    BEGIN
        SET @CodeResult = -2;
        SET @MessageResult = 'Primero envía tu solicitud de dueño.';
        RETURN;
    END

    IF @StatusID NOT IN (1, 3)
    BEGIN
        SET @PreviousUrl = NULL;
        SET @CodeResult = -3;
        SET @MessageResult = 'El documento solo se puede cambiar mientras la solicitud está pendiente o rechazada.';
        RETURN;
    END

    UPDATE [Venue].[OwnerProfiles]
    SET [DocumentUrl] = @DocumentUrl, [VerificationStatusID] = 1, [UpdateDate] = SYSUTCDATETIME()
    WHERE [UserID] = @UserID;

    SET @CodeResult = @UserID;
    SET @MessageResult = 'Documento recibido.';
END;
GO

/* ============================================================================
   REVISIÓN DE COMPLEJOS (SUPERADMIN)
   ============================================================================ */

CREATE OR ALTER PROCEDURE [Venue].[GetVenueRequests]
    @VerificationStatusID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT V.[VenueID], V.[Name], V.[Address], Z.[Name] AS [ZoneName], CI.[Name] AS [CityName],
           V.[OwnerUserID], U.[Name] AS [OwnerName], U.[Mail] AS [OwnerMail], OP.[LegalName] AS [OwnerLegalName],
           V.[VerificationStatusID], VS.[Code] AS [VerificationStatusCode], VS.[Name] AS [VerificationStatusName],
           V.[VerificationNotes], V.[StatusID], V.[CreationDate],
           (SELECT COUNT(*) FROM [Venue].[Courts] C WHERE C.[VenueID] = V.[VenueID] AND C.[StatusID] <> 3) AS [CourtCount],
           (SELECT COUNT(*) FROM [Venue].[VenuePhotos] P WHERE P.[VenueID] = V.[VenueID]) AS [PhotoCount]
    FROM [Venue].[Venues] V
    INNER JOIN [Catalog].[Zones] Z ON Z.[ZoneID] = V.[ZoneID]
    INNER JOIN [Catalog].[Cities] CI ON CI.[CityID] = Z.[CityID]
    INNER JOIN [Security].[Users] U ON U.[UserID] = V.[OwnerUserID]
    INNER JOIN [Venue].[OwnerProfiles] OP ON OP.[UserID] = V.[OwnerUserID]
    INNER JOIN [Venue].[VerificationStatuses] VS ON VS.[VerificationStatusID] = V.[VerificationStatusID]
    WHERE V.[StatusID] <> 3
      AND (@VerificationStatusID IS NULL OR V.[VerificationStatusID] = @VerificationStatusID)
    ORDER BY CASE WHEN V.[VerificationStatusID] = 1 THEN 0 ELSE 1 END, V.[CreationDate];
END;
GO

-- ===== Venue.ReviewVenue: aprobar (2), rechazar (3) o suspender (4) un complejo.
-- Al aprobarlo por primera vez se le asigna el plan de prueba (TRIAL).
CREATE OR ALTER PROCEDURE [Venue].[ReviewVenue]
    @VenueID INT,
    @VerificationStatusID INT,
    @ReviewNotes NVARCHAR(500) = NULL,
    @ReviewerUserID INT,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM [Security].[UserRoles] UR INNER JOIN [Security].[Roles] R ON R.[RoleID] = UR.[RoleID]
                       WHERE UR.[UserID] = @ReviewerUserID AND R.[Code] = 'SUPERADMIN' AND R.[StatusID] = 1)
        BEGIN
            SET @CodeResult = -403;
            SET @MessageResult = 'Solo un administrador de CUPPO puede revisar complejos.';
            RETURN;
        END

        DECLARE @Current INT = (SELECT [VerificationStatusID] FROM [Venue].[Venues] WHERE [VenueID] = @VenueID AND [StatusID] <> 3);
        IF @Current IS NULL
        BEGIN
            SET @CodeResult = -2;
            SET @MessageResult = 'El complejo no existe.';
            RETURN;
        END

        IF NOT (   (@VerificationStatusID = 2 AND @Current IN (1, 3, 4))
                OR (@VerificationStatusID = 3 AND @Current = 1)
                OR (@VerificationStatusID = 4 AND @Current = 2))
        BEGIN
            SET @CodeResult = -3;
            SET @MessageResult = 'Cambio de estado de verificación no permitido.';
            RETURN;
        END

        IF @VerificationStatusID IN (3, 4) AND NULLIF(LTRIM(RTRIM(@ReviewNotes)), N'') IS NULL
        BEGIN
            SET @CodeResult = -4;
            SET @MessageResult = 'Debe indicar el motivo del rechazo o la suspensión.';
            RETURN;
        END

        BEGIN TRANSACTION;
            UPDATE [Venue].[Venues]
            SET [VerificationStatusID] = @VerificationStatusID, [VerificationNotes] = @ReviewNotes,
                [UpdateUserID] = @ReviewerUserID, [UpdateDate] = SYSUTCDATETIME()
            WHERE [VenueID] = @VenueID;

            IF @VerificationStatusID = 2 AND NOT EXISTS (SELECT 1 FROM [Billing].[VenueSubscriptions] WHERE [VenueID] = @VenueID)
                INSERT INTO [Billing].[VenueSubscriptions] ([VenueID], [SubscriptionPlanID], [StartDate], [EndDate], [CreationUserID])
                SELECT @VenueID, [SubscriptionPlanID], CAST([Catalog].[GetLocalDateTime]() AS DATE),
                       DATEADD(DAY, [DurationDays], CAST([Catalog].[GetLocalDateTime]() AS DATE)), @ReviewerUserID
                FROM [Billing].[SubscriptionPlans] WHERE [Code] = 'TRIAL';
        COMMIT TRANSACTION;

        SET @CodeResult = @VenueID;
        SET @MessageResult = CASE @VerificationStatusID
                                 WHEN 2 THEN 'Complejo aprobado: ya aparece en la app.'
                                 WHEN 3 THEN 'Complejo rechazado.'
                                 ELSE 'Complejo suspendido: ya no aparece ni recibe reservas.' END;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();
        DECLARE @InputData VARCHAR(MAX) = CONCAT('VenueID: ', @VenueID, ' | Status: ', @VerificationStatusID);
        EXECUTE [Log].[InsertLogError] @UserId = @ReviewerUserID, @AppModule = 'Venue', @MethodName = NULL,
            @ProcedureName = '[Venue].[ReviewVenue]', @ErrorCode = @CodeResult, @ErrorMessage = @MessageResult,
            @InputData = @InputData, @ClientIP = NULL;
    END CATCH
END;
GO
