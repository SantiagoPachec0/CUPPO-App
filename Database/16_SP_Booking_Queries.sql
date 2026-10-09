USE [CUPPO];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================================
   16. RESERVAS Y PAGOS: CONSULTAS PARA LA API (Fase 3)

   - Mis reservas (jugador) y detalle de una reserva (jugador o dueño).
   - Agenda del complejo y pagos por verificar (dueño).
   - Marcar "no asistió".
   - Comprobantes de pago: solo los ven el jugador que pagó y el dueño.
   ============================================================================ */

-- ===== Booking.GetUserBookings: @Scope 'UPCOMING' (por jugar) o 'PAST' (historial)
CREATE OR ALTER PROCEDURE [Booking].[GetUserBookings]
    @UserID INT,
    @Scope VARCHAR(10) = 'UPCOMING',
    @Page INT = 1,
    @PageSize INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    SET @Page = CASE WHEN @Page IS NULL OR @Page < 1 THEN 1 ELSE @Page END;
    SET @PageSize = CASE WHEN @PageSize IS NULL OR @PageSize < 1 THEN 20 WHEN @PageSize > 50 THEN 50 ELSE @PageSize END;

    DECLARE @Now DATETIME2(0) = [Catalog].[GetLocalDateTime]();
    DECLARE @Upcoming BIT = CASE WHEN @Scope = 'PAST' THEN 0 ELSE 1 END;

    SELECT B.[BookingID], B.[StartDateTime], B.[EndDateTime], B.[TotalUSD],
           B.[BookingStatusID], BS.[Code] AS [BookingStatusCode], BS.[Name] AS [BookingStatusName], B.[ExpiresAt],
           C.[CourtID], C.[Name] AS [CourtName], S.[Name] AS [SportName],
           V.[VenueID], V.[Name] AS [VenueName], V.[Address] AS [VenueAddress],
           (SELECT TOP (1) P.[Url] FROM [Venue].[VenuePhotos] P WHERE P.[VenueID] = V.[VenueID] ORDER BY P.[IsCover] DESC, P.[DisplayOrder]) AS [CoverUrl],
           COUNT(*) OVER () AS [TotalCount]
    FROM [Booking].[Bookings] B
    INNER JOIN [Booking].[BookingStatuses] BS ON BS.[BookingStatusID] = B.[BookingStatusID]
    INNER JOIN [Venue].[Courts] C ON C.[CourtID] = B.[CourtID]
    INNER JOIN [Catalog].[Sports] S ON S.[SportID] = C.[SportID]
    INNER JOIN [Venue].[Venues] V ON V.[VenueID] = C.[VenueID]
    WHERE B.[UserID] = @UserID
      AND (   (@Upcoming = 1 AND B.[EndDateTime] > @Now AND B.[BookingStatusID] IN (1, 2, 3))
           OR (@Upcoming = 0 AND (B.[EndDateTime] <= @Now OR B.[BookingStatusID] NOT IN (1, 2, 3))))
    ORDER BY CASE WHEN @Upcoming = 1 THEN B.[StartDateTime] END ASC,
             CASE WHEN @Upcoming = 0 THEN B.[StartDateTime] END DESC
    OFFSET (@Page - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- ===== Booking.GetBookingDetail
-- La ve el jugador de la reserva o el dueño verificado del complejo.
-- Result sets: 1 reserva, 2 cuentas de cobro del complejo, 3 pagos registrados.
CREATE OR ALTER PROCEDURE [Booking].[GetBookingDetail]
    @BookingID INT,
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PlayerID INT, @VenueID INT;
    SELECT @PlayerID = B.[UserID], @VenueID = C.[VenueID]
    FROM [Booking].[Bookings] B
    INNER JOIN [Venue].[Courts] C ON C.[CourtID] = B.[CourtID]
    WHERE B.[BookingID] = @BookingID;

    DECLARE @IsPlayer BIT = CASE WHEN @PlayerID = @UserID THEN 1 ELSE 0 END;
    DECLARE @IsOwner BIT = CASE WHEN @VenueID IS NOT NULL THEN [Venue].[CanManageVenue](@UserID, @VenueID) ELSE 0 END;
    DECLARE @Allowed BIT = CASE WHEN @IsPlayer = 1 OR @IsOwner = 1 THEN 1 ELSE 0 END;
    DECLARE @Rate DECIMAL(18,4) = (SELECT TOP (1) [RatePerUSD] FROM [Catalog].[ExchangeRates] WHERE [Currency] = 'VES' ORDER BY [RateDate] DESC, [ExchangeRateID] DESC);

    SELECT B.[BookingID], B.[StartDateTime], B.[EndDateTime], B.[PriceUSD], B.[FeeUSD], B.[TotalUSD],
           @Rate AS [ExchangeRate], CAST(ROUND(B.[TotalUSD] * @Rate, 2) AS DECIMAL(14,2)) AS [TotalVES],
           B.[BookingStatusID], BS.[Code] AS [BookingStatusCode], BS.[Name] AS [BookingStatusName],
           B.[ExpiresAt], B.[Notes], B.[CancelReason], B.[CreationDate],
           C.[CourtID], C.[Name] AS [CourtName], S.[Name] AS [SportName],
           V.[VenueID], V.[Name] AS [VenueName], V.[Address] AS [VenueAddress], V.[Phone] AS [VenuePhone],
           V.[WhatsApp] AS [VenueWhatsApp], V.[Latitude], V.[Longitude], V.[CancellationHours],
           U.[UserID] AS [PlayerUserID], U.[Name] AS [PlayerName], U.[Mail] AS [PlayerMail],
           @IsOwner AS [IsOwnerView]
    FROM [Booking].[Bookings] B
    INNER JOIN [Booking].[BookingStatuses] BS ON BS.[BookingStatusID] = B.[BookingStatusID]
    INNER JOIN [Venue].[Courts] C ON C.[CourtID] = B.[CourtID]
    INNER JOIN [Catalog].[Sports] S ON S.[SportID] = C.[SportID]
    INNER JOIN [Venue].[Venues] V ON V.[VenueID] = C.[VenueID]
    INNER JOIN [Security].[Users] U ON U.[UserID] = B.[UserID]
    WHERE B.[BookingID] = @BookingID AND @Allowed = 1;

    -- Datos para pagar: solo cuentas activas
    SELECT VPA.[VenuePaymentAccountID], VPA.[PaymentMethodID], PM.[Code] AS [PaymentMethodCode], PM.[Name] AS [PaymentMethodName],
           RTRIM(PM.[Currency]) AS [Currency], PM.[RequiresReference], PM.[IsOnline],
           VPA.[BankName], VPA.[AccountHolder], VPA.[DocumentNumber], VPA.[Phone], VPA.[AccountNumber], VPA.[Email], VPA.[Notes]
    FROM [Venue].[VenuePaymentAccounts] VPA
    INNER JOIN [Catalog].[PaymentMethods] PM ON PM.[PaymentMethodID] = VPA.[PaymentMethodID]
    WHERE VPA.[VenueID] = @VenueID AND VPA.[StatusID] = 1 AND PM.[StatusID] = 1 AND @Allowed = 1
    ORDER BY PM.[DisplayOrder];

    SELECT P.[PaymentID], P.[PaymentMethodID], PM.[Name] AS [PaymentMethodName], P.[AmountPaid], RTRIM(P.[Currency]) AS [Currency],
           P.[ExchangeRate], P.[AmountUSD], P.[Reference], P.[PaymentDate], P.[PayerName],
           CAST(CASE WHEN P.[ReceiptUrl] IS NULL THEN 0 ELSE 1 END AS BIT) AS [HasReceipt],
           P.[PaymentStatusID], PS.[Code] AS [PaymentStatusCode], PS.[Name] AS [PaymentStatusName],
           P.[RejectionReason], P.[CreationDate], P.[ReviewedDate]
    FROM [Payment].[Payments] P
    INNER JOIN [Catalog].[PaymentMethods] PM ON PM.[PaymentMethodID] = P.[PaymentMethodID]
    INNER JOIN [Payment].[PaymentStatuses] PS ON PS.[PaymentStatusID] = P.[PaymentStatusID]
    WHERE P.[BookingID] = @BookingID AND @Allowed = 1
    ORDER BY P.[PaymentID] DESC;
END;
GO

-- ===== Booking.GetVenueAgenda: reservas activas del complejo entre dos fechas (hora local)
CREATE OR ALTER PROCEDURE [Booking].[GetVenueAgenda]
    @VenueID INT,
    @UserID INT,
    @From DATETIME2(0),
    @To DATETIME2(0)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT B.[BookingID], B.[StartDateTime], B.[EndDateTime], B.[TotalUSD],
           B.[BookingStatusID], BS.[Code] AS [BookingStatusCode], BS.[Name] AS [BookingStatusName], B.[ExpiresAt],
           C.[CourtID], C.[Name] AS [CourtName],
           U.[UserID] AS [PlayerUserID], U.[Name] AS [PlayerName], U.[Mail] AS [PlayerMail], B.[Notes],
           LP.[PaymentID] AS [LastPaymentID], LP.[PaymentStatusCode] AS [LastPaymentStatusCode]
    FROM [Booking].[Bookings] B
    INNER JOIN [Booking].[BookingStatuses] BS ON BS.[BookingStatusID] = B.[BookingStatusID]
    INNER JOIN [Venue].[Courts] C ON C.[CourtID] = B.[CourtID]
    INNER JOIN [Security].[Users] U ON U.[UserID] = B.[UserID]
    OUTER APPLY (SELECT TOP (1) P.[PaymentID], PS.[Code] AS [PaymentStatusCode]
                 FROM [Payment].[Payments] P
                 INNER JOIN [Payment].[PaymentStatuses] PS ON PS.[PaymentStatusID] = P.[PaymentStatusID]
                 WHERE P.[BookingID] = B.[BookingID]
                 ORDER BY P.[PaymentID] DESC) LP
    WHERE C.[VenueID] = @VenueID
      AND B.[StartDateTime] < @To AND B.[EndDateTime] > @From
      AND BS.[HoldsSlot] = 1
      AND [Venue].[CanManageVenue](@UserID, @VenueID) = 1
    ORDER BY B.[StartDateTime], C.[Name];
END;
GO

-- ===== Payment.GetPendingPayments: pagos por verificar de los complejos del dueño
CREATE OR ALTER PROCEDURE [Payment].[GetPendingPayments]
    @UserID INT,
    @VenueID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT P.[PaymentID], P.[BookingID], B.[StartDateTime], B.[EndDateTime], B.[TotalUSD],
           V.[VenueID], V.[Name] AS [VenueName], C.[Name] AS [CourtName],
           U.[Name] AS [PlayerName], U.[Mail] AS [PlayerMail],
           P.[PaymentMethodID], PM.[Name] AS [PaymentMethodName], P.[AmountPaid], RTRIM(P.[Currency]) AS [Currency],
           P.[ExchangeRate], P.[AmountUSD], P.[Reference], P.[PaymentDate], P.[PayerName], P.[PayerDocument], P.[PayerPhone],
           CAST(CASE WHEN P.[ReceiptUrl] IS NULL THEN 0 ELSE 1 END AS BIT) AS [HasReceipt],
           CAST(CASE WHEN P.[AmountUSD] + 0.01 < B.[TotalUSD] THEN 1 ELSE 0 END AS BIT) AS [IsUnderpaid],
           P.[CreationDate]
    FROM [Payment].[Payments] P
    INNER JOIN [Booking].[Bookings] B ON B.[BookingID] = P.[BookingID]
    INNER JOIN [Venue].[Courts] C ON C.[CourtID] = B.[CourtID]
    INNER JOIN [Venue].[Venues] V ON V.[VenueID] = C.[VenueID]
    INNER JOIN [Security].[Users] U ON U.[UserID] = B.[UserID]
    INNER JOIN [Catalog].[PaymentMethods] PM ON PM.[PaymentMethodID] = P.[PaymentMethodID]
    INNER JOIN [Venue].[OwnerProfiles] OP ON OP.[UserID] = V.[OwnerUserID]
    WHERE P.[PaymentStatusID] = 1
      AND V.[OwnerUserID] = @UserID
      AND OP.[VerificationStatusID] = 2
      AND V.[StatusID] <> 3
      AND (@VenueID IS NULL OR V.[VenueID] = @VenueID)
    ORDER BY P.[CreationDate];
END;
GO

-- ===== Payment.GetPaymentReceipt: URL privada del comprobante si el usuario puede verlo
CREATE OR ALTER PROCEDURE [Payment].[GetPaymentReceipt]
    @PaymentID INT,
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT P.[ReceiptUrl]
    FROM [Payment].[Payments] P
    INNER JOIN [Booking].[Bookings] B ON B.[BookingID] = P.[BookingID]
    INNER JOIN [Venue].[Courts] C ON C.[CourtID] = B.[CourtID]
    WHERE P.[PaymentID] = @PaymentID
      AND P.[ReceiptUrl] IS NOT NULL
      AND (B.[UserID] = @UserID OR [Venue].[CanManageVenue](@UserID, C.[VenueID]) = 1);
END;
GO

-- ===== Booking.MarkNoShow: el dueño marca que el jugador no asistió a una reserva confirmada que ya empezó
CREATE OR ALTER PROCEDURE [Booking].[MarkNoShow]
    @BookingID INT,
    @UserID INT,
    @CodeResult INT OUTPUT,
    @MessageResult VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @VenueID INT, @StatusID INT, @StartDateTime DATETIME2(0);
    SELECT @VenueID = C.[VenueID], @StatusID = B.[BookingStatusID], @StartDateTime = B.[StartDateTime]
    FROM [Booking].[Bookings] B
    INNER JOIN [Venue].[Courts] C ON C.[CourtID] = B.[CourtID]
    WHERE B.[BookingID] = @BookingID;

    IF @VenueID IS NULL OR [Venue].[CanManageVenue](@UserID, @VenueID) = 0
    BEGIN
        SET @CodeResult = -403;
        SET @MessageResult = 'No tienes permiso sobre esta reserva.';
        RETURN;
    END

    IF @StatusID NOT IN (3, 4)
    BEGIN
        SET @CodeResult = -2;
        SET @MessageResult = 'Solo se puede marcar "no asistió" en una reserva confirmada.';
        RETURN;
    END

    IF @StartDateTime > [Catalog].[GetLocalDateTime]()
    BEGIN
        SET @CodeResult = -3;
        SET @MessageResult = 'La reserva todavía no ha empezado.';
        RETURN;
    END

    BEGIN TRANSACTION;
        UPDATE [Booking].[Bookings] SET [BookingStatusID] = 7, [UpdateDate] = SYSUTCDATETIME() WHERE [BookingID] = @BookingID;
        INSERT INTO [Booking].[BookingStatusHistory] ([BookingID], [FromStatusID], [ToStatusID], [ChangedByUserID], [Notes])
        VALUES (@BookingID, @StatusID, 7, @UserID, N'No asistió');
    COMMIT TRANSACTION;

    SET @CodeResult = @BookingID;
    SET @MessageResult = 'Reserva marcada como "no asistió".';
END;
GO

/* ============================================================================
   Disponibilidad y creación de reservas: ahora también exigen que el dueño del
   complejo siga verificado (si CUPPO lo suspende, sus canchas dejan de recibir
   reservas). Misma lógica que en 11_SP_Booking_Payment.sql.
   ============================================================================ */

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
      AND V.[VerificationStatusID] = 2
      AND EXISTS (SELECT 1 FROM [Venue].[OwnerProfiles] OP WHERE OP.[UserID] = V.[OwnerUserID] AND OP.[VerificationStatusID] = 2);

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
          AND V.[VerificationStatusID] = 2
          AND EXISTS (SELECT 1 FROM [Venue].[OwnerProfiles] OP WHERE OP.[UserID] = V.[OwnerUserID] AND OP.[VerificationStatusID] = 2);

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

            DECLARE @BookingUserID INT, @OwnerUserID INT, @StatusID INT, @StartDateTime DATETIME2(0), @CancellationHours INT, @VenueID INT;

            SELECT @BookingUserID = B.[UserID],
                   @OwnerUserID = V.[OwnerUserID],
                   @StatusID = B.[BookingStatusID],
                   @StartDateTime = B.[StartDateTime],
                   @CancellationHours = V.[CancellationHours],
                   @VenueID = V.[VenueID]
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

            -- Dueño = dueño VERIFICADO del complejo (si CUPPO lo suspende, ya no puede gestionar reservas)
            DECLARE @IsOwner BIT = CASE WHEN @OwnerUserID = @UserID AND [Venue].[CanManageVenue](@UserID, @VenueID) = 1 THEN 1 ELSE 0 END;

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
