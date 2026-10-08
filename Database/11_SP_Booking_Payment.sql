USE [CUPPO];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================================
   11. STORED PROCEDURES: DISPONIBILIDAD, RESERVAS Y PAGOS

   Horas de cancha y reservas: hora local de Venezuela.
   ExpiresAt y fechas de auditoría: UTC.
   ============================================================================ */

-- ===== Booking.GetHalfHourSlots
-- Divide [@Start, @End) en bloques de 30 minutos y devuelve el precio por hora
-- que aplica a cada bloque (NULL si la cancha no tiene precio para esa hora).
CREATE OR ALTER FUNCTION [Booking].[GetHalfHourSlots](
    @CourtID INT,
    @Start DATETIME2(0),
    @End DATETIME2(0)
)
RETURNS TABLE
AS
RETURN
    WITH N AS (
        SELECT TOP (CASE WHEN @End > @Start THEN DATEDIFF(MINUTE, @Start, @End) / 30 ELSE 0 END)
               ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS [n]
        FROM sys.all_objects
    ),
    S AS (
        SELECT DATEADD(MINUTE, 30 * N.[n], @Start) AS [SlotStart] FROM N
    )
    SELECT S.[SlotStart], P.[PricePerHourUSD]
    FROM S
    OUTER APPLY (
        SELECT TOP (1) CP.[PricePerHourUSD]
        FROM [Venue].[CourtPrices] CP
        WHERE CP.[CourtID] = @CourtID
          AND CP.[StatusID] = 1
          AND (CP.[DayOfWeek] IS NULL OR CP.[DayOfWeek] = [Catalog].[GetIsoDayOfWeek](CAST(S.[SlotStart] AS DATE)))
          AND CAST(S.[SlotStart] AS TIME(0)) >= CP.[StartTime]
          AND (CAST(S.[SlotStart] AS TIME(0)) < CP.[EndTime] OR CP.[EndTime] = '00:00')
        -- La franja de un día específico gana sobre la general
        ORDER BY CASE WHEN CP.[DayOfWeek] IS NULL THEN 1 ELSE 0 END, CP.[CourtPriceID] DESC
    ) P;
GO

-- ===== Booking.GetCourtAvailability
-- Horarios de una cancha para una fecha, en bloques de SlotMinutes, con precio
-- y si se pueden reservar. Devuelve vacío si la cancha no está disponible.
CREATE OR ALTER PROCEDURE [Booking].[GetCourtAvailability]
    @CourtID INT,
    @Date DATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SlotMinutes INT;
    SELECT @SlotMinutes = C.[SlotMinutes]
    FROM [Venue].[Courts] C
    INNER JOIN [Venue].[Venues] V ON V.[VenueID] = C.[VenueID]
    WHERE C.[CourtID] = @CourtID
      AND C.[StatusID] = 1
      AND V.[StatusID] = 1
      AND V.[VerificationStatusID] = 2;

    IF @SlotMinutes IS NULL
    BEGIN
        SELECT CAST(NULL AS DATETIME2(0)) AS [SlotStart], CAST(NULL AS DATETIME2(0)) AS [SlotEnd],
               CAST(NULL AS DECIMAL(10,2)) AS [PriceUSD], CAST(NULL AS BIT) AS [IsAvailable]
        WHERE 1 = 0;
        RETURN;
    END

    DECLARE @Now DATETIME2(0) = [Catalog].[GetLocalDateTime]();
    DECLARE @MinStart DATETIME2(0) = DATEADD(MINUTE,
        ISNULL(TRY_CAST((SELECT [SettingValue] FROM [Catalog].[Settings] WHERE [SettingKey] = 'MIN_MINUTES_BEFORE_START') AS INT), 0), @Now);
    DECLARE @DayStart DATETIME2(0) = CAST(@Date AS DATETIME2(0));
    DECLARE @Midnight TIME(0) = '00:00';

    WITH N AS (
        SELECT TOP (48) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS [n] FROM sys.all_objects
    ),
    W AS (
        SELECT DATEADD(MINUTE, DATEDIFF(MINUTE, @Midnight, CS.[OpenTime]), @DayStart) AS [WindowStart],
               CASE WHEN CS.[CloseTime] = @Midnight THEN DATEADD(DAY, 1, @DayStart)
                    ELSE DATEADD(MINUTE, DATEDIFF(MINUTE, @Midnight, CS.[CloseTime]), @DayStart) END AS [WindowEnd]
        FROM [Venue].[CourtSchedules] CS
        WHERE CS.[CourtID] = @CourtID
          AND CS.[DayOfWeek] = [Catalog].[GetIsoDayOfWeek](@Date)
          AND CS.[StatusID] = 1
    ),
    S AS (
        SELECT DATEADD(MINUTE, N.[n] * @SlotMinutes, W.[WindowStart]) AS [SlotStart],
               DATEADD(MINUTE, (N.[n] + 1) * @SlotMinutes, W.[WindowStart]) AS [SlotEnd]
        FROM W CROSS JOIN N
        WHERE DATEADD(MINUTE, (N.[n] + 1) * @SlotMinutes, W.[WindowStart]) <= W.[WindowEnd]
    )
    SELECT S.[SlotStart],
           S.[SlotEnd],
           CAST(PR.[PriceUSD] AS DECIMAL(10,2)) AS [PriceUSD],
           CAST(CASE WHEN S.[SlotStart] >= @MinStart
                      AND PR.[MissingPrices] = 0
                      AND NOT EXISTS (SELECT 1 FROM [Booking].[BookingSlots] BS
                                      WHERE BS.[CourtID] = @CourtID
                                        AND BS.[SlotStart] >= S.[SlotStart] AND BS.[SlotStart] < S.[SlotEnd])
                      AND NOT EXISTS (SELECT 1 FROM [Venue].[CourtBlocks] CB
                                      WHERE CB.[CourtID] = @CourtID
                                        AND CB.[StartDateTime] < S.[SlotEnd] AND CB.[EndDateTime] > S.[SlotStart])
                     THEN 1 ELSE 0 END AS BIT) AS [IsAvailable]
    FROM S
    CROSS APPLY (
        SELECT SUM(H.[PricePerHourUSD]) / 2 AS [PriceUSD],
               SUM(CASE WHEN H.[PricePerHourUSD] IS NULL THEN 1 ELSE 0 END) AS [MissingPrices]
        FROM [Booking].[GetHalfHourSlots](@CourtID, S.[SlotStart], S.[SlotEnd]) H
    ) PR
    ORDER BY S.[SlotStart];
END;
GO

-- ===== Booking.CreateBooking
-- Crea una reserva en PENDING_PAYMENT y retiene la cancha por
-- Venues.BookingHoldMinutes. CodeResult = BookingID si tiene éxito.
CREATE OR ALTER PROCEDURE [Booking].[CreateBooking]
    @CourtID INT,
    @UserID INT,
    @StartDateTime DATETIME2(0),
    @DurationMinutes INT,
    @Notes NVARCHAR(500) = NULL,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EndDateTime DATETIME2(0) = DATEADD(MINUTE, @DurationMinutes, @StartDateTime);

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM [Security].[Users] WHERE [UserID] = @UserID AND [Blocked] = 0 AND [StatusID] = 1)
        BEGIN
            SET @CodeResult = -2;
            SET @MessageResult = 'El usuario no existe o se encuentra inactivo.';
            RETURN;
        END

        DECLARE @SlotMinutes INT, @HoldMinutes INT;
        SELECT @SlotMinutes = C.[SlotMinutes], @HoldMinutes = V.[BookingHoldMinutes]
        FROM [Venue].[Courts] C
        INNER JOIN [Venue].[Venues] V ON V.[VenueID] = C.[VenueID]
        WHERE C.[CourtID] = @CourtID
          AND C.[StatusID] = 1
          AND V.[StatusID] = 1
          AND V.[VerificationStatusID] = 2;

        IF @SlotMinutes IS NULL
        BEGIN
            SET @CodeResult = -3;
            SET @MessageResult = 'La cancha no está disponible para reservas.';
            RETURN;
        END

        DECLARE @MaxMinutes INT = ISNULL(TRY_CAST((SELECT [SettingValue] FROM [Catalog].[Settings] WHERE [SettingKey] = 'MAX_BOOKING_MINUTES') AS INT), 240);
        IF @DurationMinutes IS NULL OR @DurationMinutes < @SlotMinutes OR @DurationMinutes > @MaxMinutes OR @DurationMinutes % 30 <> 0
        BEGIN
            SET @CodeResult = -4;
            SET @MessageResult = CONCAT('Duración inválida. Debe ser de ', @SlotMinutes, ' a ', @MaxMinutes, ' minutos, en bloques de 30.');
            RETURN;
        END

        IF DATEPART(MINUTE, @StartDateTime) NOT IN (0, 30) OR DATEPART(SECOND, @StartDateTime) <> 0
        BEGIN
            SET @CodeResult = -5;
            SET @MessageResult = 'La hora de inicio debe ser en punto o y media.';
            RETURN;
        END

        DECLARE @Now DATETIME2(0) = [Catalog].[GetLocalDateTime]();
        DECLARE @MinMinutes INT = ISNULL(TRY_CAST((SELECT [SettingValue] FROM [Catalog].[Settings] WHERE [SettingKey] = 'MIN_MINUTES_BEFORE_START') AS INT), 0);
        DECLARE @MaxDays INT = ISNULL(TRY_CAST((SELECT [SettingValue] FROM [Catalog].[Settings] WHERE [SettingKey] = 'MAX_DAYS_AHEAD') AS INT), 30);

        IF @StartDateTime < DATEADD(MINUTE, @MinMinutes, @Now)
        BEGIN
            SET @CodeResult = -6;
            SET @MessageResult = CONCAT('Debes reservar con al menos ', @MinMinutes, ' minutos de anticipación.');
            RETURN;
        END

        IF CAST(@StartDateTime AS DATE) > DATEADD(DAY, @MaxDays, CAST(@Now AS DATE))
        BEGIN
            SET @CodeResult = -6;
            SET @MessageResult = CONCAT('Solo se puede reservar hasta ', @MaxDays, ' días hacia adelante.');
            RETURN;
        END

        -- Debe caber completa en una franja de horario de ese día
        DECLARE @Date DATE = CAST(@StartDateTime AS DATE);
        DECLARE @DayStart DATETIME2(0) = CAST(@Date AS DATETIME2(0));
        DECLARE @Midnight TIME(0) = '00:00';

        IF NOT EXISTS (
            SELECT 1
            FROM [Venue].[CourtSchedules] CS
            WHERE CS.[CourtID] = @CourtID
              AND CS.[DayOfWeek] = [Catalog].[GetIsoDayOfWeek](@Date)
              AND CS.[StatusID] = 1
              AND @StartDateTime >= DATEADD(MINUTE, DATEDIFF(MINUTE, @Midnight, CS.[OpenTime]), @DayStart)
              AND @EndDateTime <= CASE WHEN CS.[CloseTime] = @Midnight THEN DATEADD(DAY, 1, @DayStart)
                                       ELSE DATEADD(MINUTE, DATEDIFF(MINUTE, @Midnight, CS.[CloseTime]), @DayStart) END
        )
        BEGIN
            SET @CodeResult = -7;
            SET @MessageResult = 'El horario elegido está fuera del horario de la cancha.';
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM [Venue].[CourtBlocks]
                   WHERE [CourtID] = @CourtID AND [StartDateTime] < @EndDateTime AND [EndDateTime] > @StartDateTime)
        BEGIN
            SET @CodeResult = -8;
            SET @MessageResult = 'La cancha está bloqueada en ese horario.';
            RETURN;
        END

        DECLARE @PriceUSD DECIMAL(10,2), @MissingPrices INT;
        SELECT @PriceUSD = SUM([PricePerHourUSD]) / 2,
               @MissingPrices = SUM(CASE WHEN [PricePerHourUSD] IS NULL THEN 1 ELSE 0 END)
        FROM [Booking].[GetHalfHourSlots](@CourtID, @StartDateTime, @EndDateTime);

        IF @MissingPrices > 0 OR @PriceUSD IS NULL
        BEGIN
            SET @CodeResult = -9;
            SET @MessageResult = 'La cancha no tiene precio configurado para ese horario.';
            RETURN;
        END

        DECLARE @MaxPending INT = ISNULL(TRY_CAST((SELECT [SettingValue] FROM [Catalog].[Settings] WHERE [SettingKey] = 'MAX_PENDING_BOOKINGS') AS INT), 2);
        IF (SELECT COUNT(*) FROM [Booking].[Bookings]
            WHERE [UserID] = @UserID AND [BookingStatusID] = 1 AND [ExpiresAt] > SYSUTCDATETIME()) >= @MaxPending
        BEGIN
            SET @CodeResult = -10;
            SET @MessageResult = CONCAT('Tienes ', @MaxPending, ' reservas pendientes de pago. Paga o cancela alguna antes de reservar otra.');
            RETURN;
        END

        DECLARE @FeeUSD DECIMAL(10,2) = ISNULL(TRY_CAST((SELECT [SettingValue] FROM [Catalog].[Settings] WHERE [SettingKey] = 'BOOKING_FEE_USD') AS DECIMAL(10,2)), 0);

        BEGIN TRANSACTION;

            -- Las reservas de una misma cancha se procesan en fila (evita deadlocks)
            DECLARE @LockResource NVARCHAR(255) = CONCAT(N'Booking.Court.', @CourtID);
            EXEC sp_getapplock @Resource = @LockResource, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;

            INSERT INTO [Booking].[Bookings] (
                [CourtID], [UserID], [StartDateTime], [EndDateTime], [PriceUSD], [FeeUSD],
                [BookingStatusID], [ExpiresAt], [Notes]
            )
            VALUES (
                @CourtID, @UserID, @StartDateTime, @EndDateTime, @PriceUSD, @FeeUSD,
                1, DATEADD(MINUTE, @HoldMinutes, SYSUTCDATETIME()), @Notes
            );

            DECLARE @BookingID INT = SCOPE_IDENTITY();

            -- Si otro jugador ya tomó alguno de estos bloques, la PK falla (error 2627)
            INSERT INTO [Booking].[BookingSlots] ([CourtID], [SlotStart], [BookingID])
            SELECT @CourtID, [SlotStart], @BookingID
            FROM [Booking].[GetHalfHourSlots](@CourtID, @StartDateTime, @EndDateTime);

            INSERT INTO [Booking].[BookingStatusHistory] ([BookingID], [FromStatusID], [ToStatusID], [ChangedByUserID])
            VALUES (@BookingID, NULL, 1, @UserID);

            SET @CodeResult = @BookingID;
            SET @MessageResult = CONCAT('Reserva creada. Tienes ', @HoldMinutes, ' minutos para registrar el pago.');

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- 2627/2601: bloque ya tomado; 1205: deadlock con otra reserva simultánea
        IF ERROR_NUMBER() IN (2627, 2601, 1205)
        BEGIN
            SET @CodeResult = -11;
            SET @MessageResult = 'Ese horario acaba de ser reservado por otra persona. Elige otro.';
            RETURN;
        END

        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();

        DECLARE @InputData VARCHAR(MAX) = CONCAT(
            'CourtID: ', ISNULL(CAST(@CourtID AS VARCHAR(20)), 'NULL'), ' | ',
            'Start: ', ISNULL(CONVERT(VARCHAR(19), @StartDateTime, 120), 'NULL'), ' | ',
            'Duration: ', ISNULL(CAST(@DurationMinutes AS VARCHAR(20)), 'NULL')
        );

        EXECUTE [Log].[InsertLogError]
            @UserId = @UserID,
            @AppModule = 'Booking',
            @MethodName = NULL,
            @ProcedureName = '[Booking].[CreateBooking]',
            @ErrorCode = @CodeResult,
            @ErrorMessage = @MessageResult,
            @InputData = @InputData,
            @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Booking.CancelBooking
-- La puede cancelar el jugador o el dueño del complejo.
-- El jugador solo puede cancelar una reserva CONFIRMADA con
-- Venues.CancellationHours de anticipación.
CREATE OR ALTER PROCEDURE [Booking].[CancelBooking]
    @BookingID INT,
    @UserID INT,
    @Reason NVARCHAR(250) = NULL,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            DECLARE @BookingUserID INT, @OwnerUserID INT, @StatusID INT, @StartDateTime DATETIME2(0), @CancellationHours INT;

            SELECT @BookingUserID = B.[UserID],
                   @OwnerUserID = V.[OwnerUserID],
                   @StatusID = B.[BookingStatusID],
                   @StartDateTime = B.[StartDateTime],
                   @CancellationHours = V.[CancellationHours]
            FROM [Booking].[Bookings] B WITH (UPDLOCK)
            INNER JOIN [Venue].[Courts] C ON C.[CourtID] = B.[CourtID]
            INNER JOIN [Venue].[Venues] V ON V.[VenueID] = C.[VenueID]
            WHERE B.[BookingID] = @BookingID;

            IF @BookingUserID IS NULL
            BEGIN
                SET @CodeResult = -2;
                SET @MessageResult = 'La reserva no existe.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            DECLARE @IsOwner BIT = CASE WHEN @OwnerUserID = @UserID THEN 1 ELSE 0 END;

            IF @BookingUserID <> @UserID AND @IsOwner = 0
            BEGIN
                SET @CodeResult = -3;
                SET @MessageResult = 'No tienes permiso para cancelar esta reserva.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF @StatusID NOT IN (1, 2, 3)
            BEGIN
                SET @CodeResult = -4;
                SET @MessageResult = 'La reserva ya no se puede cancelar.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF @IsOwner = 0 AND @StatusID = 3
               AND @StartDateTime < DATEADD(HOUR, @CancellationHours, [Catalog].[GetLocalDateTime]())
            BEGIN
                SET @CodeResult = -5;
                SET @MessageResult = CONCAT('Solo puedes cancelar con ', @CancellationHours, ' horas de anticipación. Comunícate con el complejo.');
                ROLLBACK TRANSACTION;
                RETURN;
            END

            UPDATE [Booking].[Bookings]
            SET [BookingStatusID] = 5,
                [CancelReason] = @Reason,
                [CancelledByUserID] = @UserID,
                [ExpiresAt] = NULL,
                [UpdateDate] = SYSUTCDATETIME()
            WHERE [BookingID] = @BookingID;

            DELETE FROM [Booking].[BookingSlots] WHERE [BookingID] = @BookingID;

            INSERT INTO [Booking].[BookingStatusHistory] ([BookingID], [FromStatusID], [ToStatusID], [ChangedByUserID], [Notes])
            VALUES (@BookingID, @StatusID, 5, @UserID, @Reason);

            SET @CodeResult = @BookingID;
            SET @MessageResult = 'Reserva cancelada.';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();

        DECLARE @InputData VARCHAR(MAX) = CONCAT('BookingID: ', ISNULL(CAST(@BookingID AS VARCHAR(20)), 'NULL'));

        EXECUTE [Log].[InsertLogError]
            @UserId = @UserID,
            @AppModule = 'Booking',
            @MethodName = NULL,
            @ProcedureName = '[Booking].[CancelBooking]',
            @ErrorCode = @CodeResult,
            @ErrorMessage = @MessageResult,
            @InputData = @InputData,
            @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Booking.ExpirePendingBookings (job: cada minuto)
-- Libera las reservas que no registraron pago a tiempo. CodeResult = cantidad.
CREATE OR ALTER PROCEDURE [Booking].[ExpirePendingBookings]
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            DECLARE @Expired TABLE ([BookingID] INT PRIMARY KEY);

            UPDATE [Booking].[Bookings]
            SET [BookingStatusID] = 6,
                [UpdateDate] = SYSUTCDATETIME()
            OUTPUT inserted.[BookingID] INTO @Expired
            WHERE [BookingStatusID] = 1
              AND [ExpiresAt] <= SYSUTCDATETIME();

            DELETE BS
            FROM [Booking].[BookingSlots] BS
            INNER JOIN @Expired E ON E.[BookingID] = BS.[BookingID];

            INSERT INTO [Booking].[BookingStatusHistory] ([BookingID], [FromStatusID], [ToStatusID], [ChangedByUserID], [Notes])
            SELECT [BookingID], 1, 6, NULL, N'Vencida por falta de pago'
            FROM @Expired;

            SET @CodeResult = (SELECT COUNT(*) FROM @Expired);
            SET @MessageResult = CONCAT(@CodeResult, ' reservas vencidas.');

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();

        EXECUTE [Log].[InsertLogError]
            @UserId = NULL,
            @AppModule = 'Booking',
            @MethodName = NULL,
            @ProcedureName = '[Booking].[ExpirePendingBookings]',
            @ErrorCode = @CodeResult,
            @ErrorMessage = @MessageResult,
            @InputData = NULL,
            @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Booking.CompletePastBookings (job: cada hora)
-- Marca como COMPLETADAS las reservas confirmadas que ya terminaron.
CREATE OR ALTER PROCEDURE [Booking].[CompletePastBookings]
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            DECLARE @Completed TABLE ([BookingID] INT PRIMARY KEY);

            UPDATE [Booking].[Bookings]
            SET [BookingStatusID] = 4,
                [UpdateDate] = SYSUTCDATETIME()
            OUTPUT inserted.[BookingID] INTO @Completed
            WHERE [BookingStatusID] = 3
              AND [EndDateTime] <= [Catalog].[GetLocalDateTime]();

            INSERT INTO [Booking].[BookingStatusHistory] ([BookingID], [FromStatusID], [ToStatusID], [ChangedByUserID])
            SELECT [BookingID], 3, 4, NULL
            FROM @Completed;

            SET @CodeResult = (SELECT COUNT(*) FROM @Completed);
            SET @MessageResult = CONCAT(@CodeResult, ' reservas completadas.');

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();

        EXECUTE [Log].[InsertLogError]
            @UserId = NULL,
            @AppModule = 'Booking',
            @MethodName = NULL,
            @ProcedureName = '[Booking].[CompletePastBookings]',
            @ErrorCode = @CodeResult,
            @ErrorMessage = @MessageResult,
            @InputData = NULL,
            @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Payment.InsertPayment
-- El jugador registra su pago (referencia + comprobante). La reserva pasa a
-- PAYMENT_REVIEW y deja de vencer. CodeResult = PaymentID.
CREATE OR ALTER PROCEDURE [Payment].[InsertPayment]
    @BookingID INT,
    @UserID INT,
    @PaymentMethodID INT,
    @VenuePaymentAccountID INT = NULL,
    @AmountPaid DECIMAL(14,2),
    @PaymentDate DATE,
    @Reference VARCHAR(50) = NULL,
    @ReceiptUrl VARCHAR(500) = NULL,
    @PayerName NVARCHAR(150) = NULL,
    @PayerDocument VARCHAR(20) = NULL,
    @PayerPhone VARCHAR(20) = NULL,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            DECLARE @BookingUserID INT, @StatusID INT, @ExpiresAt DATETIME2(0), @VenueID INT;

            SELECT @BookingUserID = B.[UserID],
                   @StatusID = B.[BookingStatusID],
                   @ExpiresAt = B.[ExpiresAt],
                   @VenueID = C.[VenueID]
            FROM [Booking].[Bookings] B WITH (UPDLOCK)
            INNER JOIN [Venue].[Courts] C ON C.[CourtID] = B.[CourtID]
            WHERE B.[BookingID] = @BookingID;

            IF @BookingUserID IS NULL OR @BookingUserID <> @UserID
            BEGIN
                SET @CodeResult = -2;
                SET @MessageResult = 'La reserva no existe.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF @StatusID <> 1
            BEGIN
                SET @CodeResult = -3;
                SET @MessageResult = 'La reserva no está pendiente de pago.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF @ExpiresAt <= SYSUTCDATETIME()
            BEGIN
                SET @CodeResult = -4;
                SET @MessageResult = 'Se venció el tiempo para pagar esta reserva. Haz una nueva reserva.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            DECLARE @Currency CHAR(4), @RequiresReference BIT, @IsOnline BIT;
            SELECT @Currency = [Currency], @RequiresReference = [RequiresReference], @IsOnline = [IsOnline]
            FROM [Catalog].[PaymentMethods]
            WHERE [PaymentMethodID] = @PaymentMethodID AND [StatusID] = 1;

            IF @Currency IS NULL
            BEGIN
                SET @CodeResult = -5;
                SET @MessageResult = 'Método de pago no válido.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF (@IsOnline = 1 AND @VenuePaymentAccountID IS NULL)
               OR (@VenuePaymentAccountID IS NOT NULL AND NOT EXISTS (
                       SELECT 1 FROM [Venue].[VenuePaymentAccounts]
                       WHERE [VenuePaymentAccountID] = @VenuePaymentAccountID
                         AND [VenueID] = @VenueID
                         AND [PaymentMethodID] = @PaymentMethodID
                         AND [StatusID] = 1))
            BEGIN
                SET @CodeResult = -6;
                SET @MessageResult = 'La cuenta de cobro no corresponde a este complejo o método de pago.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF @RequiresReference = 1 AND NULLIF(LTRIM(RTRIM(@Reference)), '') IS NULL
            BEGIN
                SET @CodeResult = -7;
                SET @MessageResult = 'Debes indicar el número de referencia del pago.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF @AmountPaid IS NULL OR @AmountPaid <= 0
            BEGIN
                SET @CodeResult = -8;
                SET @MessageResult = 'El monto pagado debe ser mayor que cero.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            DECLARE @ExchangeRate DECIMAL(18,4) = NULL;
            DECLARE @AmountUSD DECIMAL(10,2) = @AmountPaid;

            IF @Currency = 'VES'
            BEGIN
                SELECT TOP (1) @ExchangeRate = [RatePerUSD]
                FROM [Catalog].[ExchangeRates]
                WHERE [Currency] = 'VES' AND [RateDate] <= @PaymentDate
                ORDER BY [RateDate] DESC;

                IF @ExchangeRate IS NULL
                BEGIN
                    SET @CodeResult = -9;
                    SET @MessageResult = 'No hay tasa BCV registrada para la fecha del pago.';
                    ROLLBACK TRANSACTION;
                    RETURN;
                END

                SET @AmountUSD = ROUND(@AmountPaid / @ExchangeRate, 2);
            END

            INSERT INTO [Payment].[Payments] (
                [BookingID], [PaymentMethodID], [VenuePaymentAccountID], [AmountPaid], [Currency],
                [ExchangeRate], [AmountUSD], [Reference], [ReceiptUrl], [PayerName], [PayerDocument],
                [PayerPhone], [PaymentDate], [PaymentStatusID], [CreationUserID]
            )
            VALUES (
                @BookingID, @PaymentMethodID, @VenuePaymentAccountID, @AmountPaid, @Currency,
                @ExchangeRate, @AmountUSD, NULLIF(LTRIM(RTRIM(@Reference)), ''), @ReceiptUrl, @PayerName, @PayerDocument,
                @PayerPhone, @PaymentDate, 1, @UserID
            );

            DECLARE @PaymentID INT = SCOPE_IDENTITY();

            UPDATE [Booking].[Bookings]
            SET [BookingStatusID] = 2,
                [ExpiresAt] = NULL,
                [UpdateDate] = SYSUTCDATETIME()
            WHERE [BookingID] = @BookingID;

            INSERT INTO [Booking].[BookingStatusHistory] ([BookingID], [FromStatusID], [ToStatusID], [ChangedByUserID], [Notes])
            VALUES (@BookingID, 1, 2, @UserID, CONCAT(N'Pago registrado #', @PaymentID));

            SET @CodeResult = @PaymentID;
            SET @MessageResult = 'Pago registrado. El complejo lo verificará en breve.';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        IF ERROR_NUMBER() IN (2627, 2601)
        BEGIN
            SET @CodeResult = -10;
            SET @MessageResult = 'Esa referencia de pago ya fue registrada.';
            RETURN;
        END

        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();

        DECLARE @InputData VARCHAR(MAX) = CONCAT(
            'BookingID: ', ISNULL(CAST(@BookingID AS VARCHAR(20)), 'NULL'), ' | ',
            'PaymentMethodID: ', ISNULL(CAST(@PaymentMethodID AS VARCHAR(20)), 'NULL'), ' | ',
            'Reference: ', ISNULL(@Reference, 'NULL')
        );

        EXECUTE [Log].[InsertLogError]
            @UserId = @UserID,
            @AppModule = 'Payment',
            @MethodName = NULL,
            @ProcedureName = '[Payment].[InsertPayment]',
            @ErrorCode = @CodeResult,
            @ErrorMessage = @MessageResult,
            @InputData = @InputData,
            @ClientIP = NULL;
    END CATCH
END;
GO

-- ===== Payment.ReviewPayment
-- El dueño (verificado) del complejo aprueba o rechaza el pago.
-- Aprobar → reserva CONFIRMED. Rechazar → reserva vuelve a PENDING_PAYMENT
-- con un nuevo tiempo límite para que el jugador corrija el pago.
CREATE OR ALTER PROCEDURE [Payment].[ReviewPayment]
    @PaymentID INT,
    @ReviewerUserID INT,
    @Approve BIT,
    @RejectionReason NVARCHAR(250) = NULL,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            DECLARE @BookingID INT, @PaymentStatusID INT, @BookingStatusID INT, @OwnerUserID INT, @HoldMinutes INT;

            SELECT @BookingID = P.[BookingID],
                   @PaymentStatusID = P.[PaymentStatusID],
                   @BookingStatusID = B.[BookingStatusID],
                   @OwnerUserID = V.[OwnerUserID],
                   @HoldMinutes = V.[BookingHoldMinutes]
            FROM [Payment].[Payments] P WITH (UPDLOCK)
            INNER JOIN [Booking].[Bookings] B WITH (UPDLOCK) ON B.[BookingID] = P.[BookingID]
            INNER JOIN [Venue].[Courts] C ON C.[CourtID] = B.[CourtID]
            INNER JOIN [Venue].[Venues] V ON V.[VenueID] = C.[VenueID]
            WHERE P.[PaymentID] = @PaymentID;

            IF @BookingID IS NULL
            BEGIN
                SET @CodeResult = -2;
                SET @MessageResult = 'El pago no existe.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF NOT (@OwnerUserID = @ReviewerUserID
                    AND EXISTS (SELECT 1 FROM [Venue].[OwnerProfiles]
                                WHERE [UserID] = @ReviewerUserID AND [VerificationStatusID] = 2))
            BEGIN
                SET @CodeResult = -3;
                SET @MessageResult = 'Solo el dueño verificado del complejo puede revisar este pago.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF @PaymentStatusID <> 1
            BEGIN
                SET @CodeResult = -4;
                SET @MessageResult = 'Este pago ya fue revisado.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            IF @Approve = 0 AND NULLIF(LTRIM(RTRIM(@RejectionReason)), N'') IS NULL
            BEGIN
                SET @CodeResult = -5;
                SET @MessageResult = 'Debes indicar el motivo del rechazo.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            UPDATE [Payment].[Payments]
            SET [PaymentStatusID] = CASE WHEN @Approve = 1 THEN 2 ELSE 3 END,
                [ReviewedByUserID] = @ReviewerUserID,
                [ReviewedDate] = SYSUTCDATETIME(),
                [RejectionReason] = CASE WHEN @Approve = 1 THEN NULL ELSE @RejectionReason END
            WHERE [PaymentID] = @PaymentID;

            -- Solo mueve la reserva si sigue esperando revisión (pudo haber sido cancelada)
            IF @BookingStatusID = 2
            BEGIN
                DECLARE @NewStatusID INT = CASE WHEN @Approve = 1 THEN 3 ELSE 1 END;

                UPDATE [Booking].[Bookings]
                SET [BookingStatusID] = @NewStatusID,
                    [ExpiresAt] = CASE WHEN @Approve = 1 THEN NULL ELSE DATEADD(MINUTE, @HoldMinutes, SYSUTCDATETIME()) END,
                    [UpdateDate] = SYSUTCDATETIME()
                WHERE [BookingID] = @BookingID;

                INSERT INTO [Booking].[BookingStatusHistory] ([BookingID], [FromStatusID], [ToStatusID], [ChangedByUserID], [Notes])
                VALUES (@BookingID, 2, @NewStatusID, @ReviewerUserID,
                        CASE WHEN @Approve = 1 THEN CONCAT(N'Pago #', @PaymentID, N' aprobado')
                             ELSE CONCAT(N'Pago #', @PaymentID, N' rechazado: ', @RejectionReason) END);
            END

            SET @CodeResult = @PaymentID;
            SET @MessageResult = CASE WHEN @Approve = 1 THEN 'Pago aprobado. La reserva quedó confirmada.'
                                      ELSE 'Pago rechazado. El jugador puede registrar un nuevo pago.' END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @CodeResult = -1;
        SET @MessageResult = ERROR_MESSAGE();

        DECLARE @InputData VARCHAR(MAX) = CONCAT(
            'PaymentID: ', ISNULL(CAST(@PaymentID AS VARCHAR(20)), 'NULL'), ' | ',
            'Approve: ', ISNULL(CAST(@Approve AS VARCHAR(1)), 'NULL')
        );

        EXECUTE [Log].[InsertLogError]
            @UserId = @ReviewerUserID,
            @AppModule = 'Payment',
            @MethodName = NULL,
            @ProcedureName = '[Payment].[ReviewPayment]',
            @ErrorCode = @CodeResult,
            @ErrorMessage = @MessageResult,
            @InputData = @InputData,
            @ClientIP = NULL;
    END CATCH
END;
GO
