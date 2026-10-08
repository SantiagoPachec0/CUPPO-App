/* ============================================================================
   PRUEBAS DE LA FASE 1 — SOLO EN UNA BASE DE PRUEBAS (ej. CUPPO_Test).
   Deja datos de prueba, por eso se niega a correr en la base CUPPO.
   Requiere los scripts 00–11 y dev/01_DemoData.sql aplicados en esa base.
   Cada línea del resultado dice OK o FALLA.
   ============================================================================ */

IF DB_NAME() = 'CUPPO'
BEGIN
    RAISERROR('Estas pruebas dejan datos: ejecútalas en una base de pruebas, no en CUPPO.', 16, 1);
    SET NOEXEC ON;
END
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;

DECLARE @Code INT, @Msg VARCHAR(MAX), @Fails INT = 0;
DECLARE @Check TABLE ([Name] VARCHAR(100), [Ok] BIT, [Detail] VARCHAR(MAX));

-- ---------- Usuarios de prueba
EXEC [Security].[InsertUser] @UserLogin = 't_jugador1', @Name = 'Jugador 1', @Mail = 't1@cuppo.local', @Password = 'Prueba123!',
     @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
DECLARE @P1 INT = @Code;
EXEC [Security].[InsertUser] @UserLogin = 't_jugador2', @Name = 'Jugador 2', @Mail = 't2@cuppo.local', @Password = 'Prueba123!',
     @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
DECLARE @P2 INT = @Code;

INSERT @Check SELECT 'Usuario nuevo recibe rol CLIENT',
    CASE WHEN EXISTS (SELECT 1 FROM [Security].[UserRoles] UR JOIN [Security].[Roles] R ON R.[RoleID] = UR.[RoleID]
                      WHERE UR.[UserID] = @P1 AND R.[Code] = 'CLIENT') THEN 1 ELSE 0 END, NULL;

DECLARE @Perms TABLE (ModuleID INT, ModuleCode VARCHAR(20), ModuleName VARCHAR(50), ParentModuleID INT, Icon VARCHAR(50),
                      Route VARCHAR(100), DisplayOrder INT, ActionID INT, ActionCode VARCHAR(20), ActionName VARCHAR(50));
INSERT @Perms EXEC [Security].[GetUserPermissions] @UserID = @P1;
INSERT @Check SELECT 'Jugador ve Mis reservas y NO el Panel de dueño',
    CASE WHEN EXISTS (SELECT 1 FROM @Perms WHERE ModuleCode = 'MOD_BOOKINGS')
          AND NOT EXISTS (SELECT 1 FROM @Perms WHERE ModuleCode = 'MOD_OWNER') THEN 1 ELSE 0 END, NULL;

-- ---------- Verificación de dueño
DECLARE @AdminID INT = (SELECT TOP (1) UR.[UserID] FROM [Security].[UserRoles] UR JOIN [Security].[Roles] R ON R.[RoleID] = UR.[RoleID]
                        WHERE R.[Code] = 'SUPERADMIN' ORDER BY UR.[UserID]);

EXEC [Venue].[RequestOwnerVerification] @UserID = @P2, @DocumentType = 'V', @DocumentNumber = '12345678',
     @LegalName = N'Jugador Dos', @Phone = '04140000000', @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
INSERT @Check SELECT 'Solicitud de dueño queda pendiente', CASE WHEN @Code = @P2 THEN 1 ELSE 0 END, @Msg;

-- Rol asignado a mano sin verificación: no debe dar el panel
INSERT INTO [Security].[UserRoles] ([UserID], [RoleID], [CreationUserID])
SELECT @P2, [RoleID], 1 FROM [Security].[Roles] WHERE [Code] = 'COMPLEX_ADMIN';
DELETE FROM @Perms;
INSERT @Perms EXEC [Security].[GetUserPermissions] @UserID = @P2;
INSERT @Check SELECT 'Rol COMPLEX_ADMIN sin verificar NO muestra el panel',
    CASE WHEN NOT EXISTS (SELECT 1 FROM @Perms WHERE ModuleCode = 'MOD_OWNER') THEN 1 ELSE 0 END, NULL;
DELETE UR FROM [Security].[UserRoles] UR JOIN [Security].[Roles] R ON R.[RoleID] = UR.[RoleID]
WHERE UR.[UserID] = @P2 AND R.[Code] = 'COMPLEX_ADMIN';

EXEC [Venue].[ReviewOwnerVerification] @UserID = @P2, @VerificationStatusID = 2, @ReviewerUserID = @P1,
     @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
INSERT @Check SELECT 'Un jugador no puede aprobar dueños', CASE WHEN @Code = -2 THEN 1 ELSE 0 END, @Msg;

EXEC [Venue].[ReviewOwnerVerification] @UserID = @P2, @VerificationStatusID = 2, @ReviewerUserID = @AdminID,
     @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
DELETE FROM @Perms;
INSERT @Perms EXEC [Security].[GetUserPermissions] @UserID = @P2;
INSERT @Check SELECT 'Dueño aprobado ve el Panel de dueño',
    CASE WHEN @Code = @P2 AND EXISTS (SELECT 1 FROM @Perms WHERE ModuleCode = 'MOD_OWNER')
          AND EXISTS (SELECT 1 FROM @Perms WHERE ModuleCode = 'MOD_BOOKINGS') THEN 1 ELSE 0 END, @Msg;

EXEC [Venue].[ReviewOwnerVerification] @UserID = @P2, @VerificationStatusID = 4, @ReviewNotes = N'Prueba', @ReviewerUserID = @AdminID,
     @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
DELETE FROM @Perms;
INSERT @Perms EXEC [Security].[GetUserPermissions] @UserID = @P2;
INSERT @Check SELECT 'Dueño suspendido pierde el panel',
    CASE WHEN @Code = @P2 AND NOT EXISTS (SELECT 1 FROM @Perms WHERE ModuleCode = 'MOD_OWNER') THEN 1 ELSE 0 END, @Msg;

-- ---------- Disponibilidad
DECLARE @Court INT = (SELECT C.[CourtID] FROM [Venue].[Courts] C JOIN [Venue].[Venues] V ON V.[VenueID] = C.[VenueID]
                      WHERE V.[Name] = N'Complejo Demo Los Palos Grandes' AND C.[Name] = N'Fútbol 5 - Cancha 1');
DECLARE @Day DATE = DATEADD(DAY, 2, CAST([Catalog].[GetLocalDateTime]() AS DATE));
-- Asegura un día de semana (lunes a viernes) para tener precios simples
WHILE [Catalog].[GetIsoDayOfWeek](@Day) > 5 SET @Day = DATEADD(DAY, 1, @Day);

DECLARE @Avail TABLE (SlotStart DATETIME2(0), SlotEnd DATETIME2(0), PriceUSD DECIMAL(10,2), IsAvailable BIT);
INSERT @Avail EXEC [Booking].[GetCourtAvailability] @CourtID = @Court, @Date = @Day;
INSERT @Check SELECT 'Disponibilidad: 16 bloques de 08:00 a 00:00',
    CASE WHEN (SELECT COUNT(*) FROM @Avail) = 16 AND (SELECT MAX(SlotEnd) FROM @Avail) = DATEADD(DAY, 1, CAST(@Day AS DATETIME2(0))) THEN 1 ELSE 0 END,
    CONCAT((SELECT COUNT(*) FROM @Avail), ' bloques');
INSERT @Check SELECT 'Precio día $30 y noche $40',
    CASE WHEN (SELECT PriceUSD FROM @Avail WHERE CAST(SlotStart AS TIME) = '10:00') = 30
          AND (SELECT PriceUSD FROM @Avail WHERE CAST(SlotStart AS TIME) = '20:00') = 40 THEN 1 ELSE 0 END, NULL;

-- ---------- Reservas
DECLARE @Start DATETIME2(0) = DATEADD(HOUR, 17, CAST(@Day AS DATETIME2(0)));   -- 17:00

EXEC [Booking].[CreateBooking] @CourtID = @Court, @UserID = @P1, @StartDateTime = @Start, @DurationMinutes = 90,
     @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
DECLARE @B1 INT = @Code;
INSERT @Check SELECT 'Reserva 17:00-18:30 cruza tarifas: 30 + 40/2 = $50',
    CASE WHEN @B1 > 0 AND (SELECT PriceUSD FROM [Booking].[Bookings] WHERE BookingID = @B1) = 50.00
          AND (SELECT COUNT(*) FROM [Booking].[BookingSlots] WHERE BookingID = @B1) = 3 THEN 1 ELSE 0 END, @Msg;

DECLARE @Overlap DATETIME2(0) = DATEADD(MINUTE, 60, @Start);   -- 18:00, se pisa con 18:00-18:30
EXEC [Booking].[CreateBooking] @CourtID = @Court, @UserID = @P2, @StartDateTime = @Overlap, @DurationMinutes = 60,
     @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
INSERT @Check SELECT 'Reserva que se pisa es rechazada (-11)', CASE WHEN @Code = -11 THEN 1 ELSE 0 END, @Msg;

DECLARE @Next DATETIME2(0) = DATEADD(MINUTE, 90, @Start);   -- 18:30, justo al terminar
EXEC [Booking].[CreateBooking] @CourtID = @Court, @UserID = @P2, @StartDateTime = @Next, @DurationMinutes = 60,
     @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
DECLARE @B2 INT = @Code;
INSERT @Check SELECT 'Reserva contigua (18:30) sí se permite', CASE WHEN @B2 > 0 THEN 1 ELSE 0 END, @Msg;

EXEC [Booking].[CreateBooking] @CourtID = @Court, @UserID = @P1, @StartDateTime = @Start, @DurationMinutes = 45,
     @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
INSERT @Check SELECT 'Duración de 45 min rechazada (-4)', CASE WHEN @Code = -4 THEN 1 ELSE 0 END, @Msg;

DECLARE @Early DATETIME2(0) = DATEADD(HOUR, 6, CAST(@Day AS DATETIME2(0)));
EXEC [Booking].[CreateBooking] @CourtID = @Court, @UserID = @P1, @StartDateTime = @Early, @DurationMinutes = 60,
     @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
INSERT @Check SELECT 'Fuera de horario (06:00) rechazada (-7)', CASE WHEN @Code = -7 THEN 1 ELSE 0 END, @Msg;

DECLARE @Late DATETIME2(0) = DATEADD(HOUR, 23, CAST(@Day AS DATETIME2(0)));
EXEC [Booking].[CreateBooking] @CourtID = @Court, @UserID = @P1, @StartDateTime = @Late, @DurationMinutes = 60,
     @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
DECLARE @B3 INT = @Code;
INSERT @Check SELECT 'Reserva 23:00-00:00 (hasta medianoche) se permite', CASE WHEN @B3 > 0 THEN 1 ELSE 0 END, @Msg;

DECLARE @Past DATETIME2(0) = DATEADD(HOUR, 17, CAST(DATEADD(DAY, -1, CAST([Catalog].[GetLocalDateTime]() AS DATE)) AS DATETIME2(0)));   -- ayer 17:00
EXEC [Booking].[CreateBooking] @CourtID = @Court, @UserID = @P2, @StartDateTime = @Past, @DurationMinutes = 60,
     @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
INSERT @Check SELECT 'Fecha pasada rechazada (-6)', CASE WHEN @Code = -6 THEN 1 ELSE 0 END, @Msg;

DECLARE @Third DATETIME2(0) = DATEADD(HOUR, 10, CAST(@Day AS DATETIME2(0)));
EXEC [Booking].[CreateBooking] @CourtID = @Court, @UserID = @P1, @StartDateTime = @Third, @DurationMinutes = 60,
     @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
INSERT @Check SELECT 'Tercera reserva sin pagar rechazada (-10)', CASE WHEN @Code = -10 THEN 1 ELSE 0 END, @Msg;

INSERT INTO [Venue].[CourtBlocks] ([CourtID], [StartDateTime], [EndDateTime], [Reason], [CreationUserID])
VALUES (@Court, DATEADD(HOUR, 12, CAST(@Day AS DATETIME2(0))), DATEADD(HOUR, 14, CAST(@Day AS DATETIME2(0))), N'Mantenimiento', 1);
DECLARE @Blocked DATETIME2(0) = DATEADD(MINUTE, 13 * 60, CAST(@Day AS DATETIME2(0)));
EXEC [Booking].[CreateBooking] @CourtID = @Court, @UserID = @P2, @StartDateTime = @Blocked, @DurationMinutes = 60,
     @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
INSERT @Check SELECT 'Horario bloqueado rechazado (-8)', CASE WHEN @Code = -8 THEN 1 ELSE 0 END, @Msg;

DELETE FROM @Avail;
INSERT @Avail EXEC [Booking].[GetCourtAvailability] @CourtID = @Court, @Date = @Day;
INSERT @Check SELECT 'Disponibilidad marca ocupados 17:00, 18:00, 12:00, 13:00 y libre 10:00',
    CASE WHEN (SELECT IsAvailable FROM @Avail WHERE CAST(SlotStart AS TIME) = '17:00') = 0
          AND (SELECT IsAvailable FROM @Avail WHERE CAST(SlotStart AS TIME) = '18:00') = 0
          AND (SELECT IsAvailable FROM @Avail WHERE CAST(SlotStart AS TIME) = '12:00') = 0
          AND (SELECT IsAvailable FROM @Avail WHERE CAST(SlotStart AS TIME) = '13:00') = 0
          AND (SELECT IsAvailable FROM @Avail WHERE CAST(SlotStart AS TIME) = '10:00') = 1 THEN 1 ELSE 0 END, NULL;

-- ---------- Pagos
DECLARE @Account INT = (SELECT TOP (1) VPA.[VenuePaymentAccountID] FROM [Venue].[VenuePaymentAccounts] VPA
                        JOIN [Venue].[Courts] C ON C.[VenueID] = VPA.[VenueID] WHERE C.[CourtID] = @Court);
DECLARE @PagoMovil INT = (SELECT [PaymentMethodID] FROM [Catalog].[PaymentMethods] WHERE [Code] = 'PAGO_MOVIL');
DECLARE @Today DATE = CAST(GETDATE() AS DATE);

EXEC [Payment].[InsertPayment] @BookingID = @B1, @UserID = @P2, @PaymentMethodID = @PagoMovil, @VenuePaymentAccountID = @Account,
     @AmountPaid = 10000, @PaymentDate = @Today, @Reference = '000111', @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
INSERT @Check SELECT 'No se puede pagar la reserva de otro (-2)', CASE WHEN @Code = -2 THEN 1 ELSE 0 END, @Msg;

EXEC [Payment].[InsertPayment] @BookingID = @B1, @UserID = @P1, @PaymentMethodID = @PagoMovil, @VenuePaymentAccountID = @Account,
     @AmountPaid = 10000, @PaymentDate = @Today, @Reference = '000111', @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
DECLARE @Pay1 INT = @Code;
INSERT @Check SELECT 'Pago en Bs convierte con tasa BCV (10000 / 200 = $50) y pasa a revisión',
    CASE WHEN @Pay1 > 0 AND (SELECT AmountUSD FROM [Payment].[Payments] WHERE PaymentID = @Pay1) = 50.00
          AND (SELECT BookingStatusID FROM [Booking].[Bookings] WHERE BookingID = @B1) = 2 THEN 1 ELSE 0 END, @Msg;

EXEC [Payment].[InsertPayment] @BookingID = @B2, @UserID = @P2, @PaymentMethodID = @PagoMovil, @VenuePaymentAccountID = @Account,
     @AmountPaid = 8000, @PaymentDate = @Today, @Reference = '000111', @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
INSERT @Check SELECT 'Referencia repetida en la misma cuenta rechazada (-10)', CASE WHEN @Code = -10 THEN 1 ELSE 0 END, @Msg;

DECLARE @OwnerID INT = (SELECT [UserID] FROM [Security].[Users] WHERE [UserLogin] = 'demo_dueno');
EXEC [Payment].[ReviewPayment] @PaymentID = @Pay1, @ReviewerUserID = @P2, @Approve = 1, @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
INSERT @Check SELECT 'Solo el dueño del complejo revisa el pago (-3)', CASE WHEN @Code = -3 THEN 1 ELSE 0 END, @Msg;

EXEC [Payment].[ReviewPayment] @PaymentID = @Pay1, @ReviewerUserID = @OwnerID, @Approve = 0, @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
INSERT @Check SELECT 'Rechazo sin motivo no se permite (-5)', CASE WHEN @Code = -5 THEN 1 ELSE 0 END, @Msg;

EXEC [Payment].[ReviewPayment] @PaymentID = @Pay1, @ReviewerUserID = @OwnerID, @Approve = 1, @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
INSERT @Check SELECT 'Dueño aprueba → reserva CONFIRMADA',
    CASE WHEN @Code = @Pay1 AND (SELECT BookingStatusID FROM [Booking].[Bookings] WHERE BookingID = @B1) = 3 THEN 1 ELSE 0 END, @Msg;

-- ---------- Cancelaciones y vencimientos
EXEC [Booking].[CancelBooking] @BookingID = @B1, @UserID = @P2, @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
INSERT @Check SELECT 'Otro jugador no puede cancelar (-3)', CASE WHEN @Code = -3 THEN 1 ELSE 0 END, @Msg;

EXEC [Booking].[CancelBooking] @BookingID = @B3, @UserID = @P1, @Reason = N'Ya no puedo', @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
INSERT @Check SELECT 'Jugador cancela su reserva pendiente y libera los bloques',
    CASE WHEN @Code = @B3 AND NOT EXISTS (SELECT 1 FROM [Booking].[BookingSlots] WHERE BookingID = @B3) THEN 1 ELSE 0 END, @Msg;

UPDATE [Booking].[Bookings] SET [ExpiresAt] = DATEADD(MINUTE, -1, SYSUTCDATETIME()) WHERE [BookingID] = @B2;
EXEC [Booking].[ExpirePendingBookings] @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
INSERT @Check SELECT 'Job vence la reserva sin pago y libera los bloques',
    CASE WHEN (SELECT BookingStatusID FROM [Booking].[Bookings] WHERE BookingID = @B2) = 6
          AND NOT EXISTS (SELECT 1 FROM [Booking].[BookingSlots] WHERE BookingID = @B2) THEN 1 ELSE 0 END, @Msg;

EXEC [Booking].[CreateBooking] @CourtID = @Court, @UserID = @P2, @StartDateTime = @Next, @DurationMinutes = 60,
     @CodeResult = @Code OUTPUT, @MessageResult = @Msg OUTPUT;
INSERT @Check SELECT 'El horario liberado se puede volver a reservar', CASE WHEN @Code > 0 THEN 1 ELSE 0 END, @Msg;

-- ---------- Resultado

SELECT CASE WHEN [Ok] = 1 THEN 'OK   ' ELSE 'FALLA' END AS [Resultado], [Name] AS [Prueba], [Detail] AS [Detalle] FROM @Check;
SELECT SUM(CASE WHEN [Ok] = 1 THEN 1 ELSE 0 END) AS [OK], SUM(CASE WHEN [Ok] = 0 THEN 1 ELSE 0 END) AS [Fallas] FROM @Check;
GO
SET NOEXEC OFF;
GO
