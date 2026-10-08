USE [CUPPO];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================================
   07. RESERVAS (esquema [Booking])

   Regla principal: dos reservas activas nunca pueden ocupar la misma cancha
   a la misma hora. Se garantiza en la base con [Booking].[BookingSlots]:
   cada reserva activa ocupa bloques de 30 minutos y la PK (CourtID, SlotStart)
   impide que dos reservas tomen el mismo bloque, aunque lleguen al mismo
   tiempo. Al cancelar o vencer una reserva se borran sus bloques.

   Flujo de estados:
   PENDING_PAYMENT → PAYMENT_REVIEW → CONFIRMED → COMPLETED
         ↓                 ↓              ↓
      EXPIRED          (rechazo:       CANCELLED / NO_SHOW
                    vuelve a PENDING_PAYMENT)
   ============================================================================ */

IF SCHEMA_ID('Booking') IS NULL EXEC('CREATE SCHEMA [Booking]');
GO

-- ===== Booking.BookingStatuses
CREATE TABLE [Booking].[BookingStatuses](
    [BookingStatusID] INT         NOT NULL,
    [Code]            VARCHAR(20) NOT NULL,
    [Name]            VARCHAR(50) NOT NULL,
    [HoldsSlot]       BIT         NOT NULL,   -- 1 = la reserva ocupa la cancha
    CONSTRAINT [PK_BookingStatuses] PRIMARY KEY CLUSTERED ([BookingStatusID]),
    CONSTRAINT [UQ_BookingStatuses_Code] UNIQUE ([Code])
);
GO

-- ===== Booking.Bookings
-- StartDateTime / EndDateTime: hora local de Venezuela.
-- ExpiresAt, CreationDate, UpdateDate: UTC.
CREATE TABLE [Booking].[Bookings](
    [BookingID]          INT IDENTITY(1,1) NOT NULL,
    [CourtID]            INT            NOT NULL,
    [UserID]             INT            NOT NULL,
    [StartDateTime]      DATETIME2(0)   NOT NULL,
    [EndDateTime]        DATETIME2(0)   NOT NULL,
    [PriceUSD]           DECIMAL(10,2)  NOT NULL,   -- precio de la cancha
    [FeeUSD]             DECIMAL(10,2)  NOT NULL CONSTRAINT [DF_Bookings_FeeUSD] DEFAULT (0),   -- comisión CUPPO
    [TotalUSD]           AS ([PriceUSD] + [FeeUSD]) PERSISTED,
    [BookingStatusID]    INT            NOT NULL,
    [ExpiresAt]          DATETIME2(0)   NULL,       -- límite para pagar (solo PENDING_PAYMENT)
    [Notes]              NVARCHAR(500)  NULL,
    [CancelReason]       NVARCHAR(250)  NULL,
    [CancelledByUserID]  INT            NULL,
    [CreationDate]       DATETIME2(0)   NOT NULL CONSTRAINT [DF_Bookings_CreationDate] DEFAULT (SYSUTCDATETIME()),
    [UpdateDate]         DATETIME2(0)   NULL,
    CONSTRAINT [PK_Bookings] PRIMARY KEY CLUSTERED ([BookingID]),
    CONSTRAINT [FK_Bookings_Courts] FOREIGN KEY ([CourtID]) REFERENCES [Venue].[Courts]([CourtID]),
    CONSTRAINT [FK_Bookings_Users] FOREIGN KEY ([UserID]) REFERENCES [Security].[Users]([UserID]),
    CONSTRAINT [FK_Bookings_CancelledBy] FOREIGN KEY ([CancelledByUserID]) REFERENCES [Security].[Users]([UserID]),
    CONSTRAINT [FK_Bookings_BookingStatuses] FOREIGN KEY ([BookingStatusID]) REFERENCES [Booking].[BookingStatuses]([BookingStatusID]),
    CONSTRAINT [CK_Bookings_Range] CHECK ([EndDateTime] > [StartDateTime]),
    CONSTRAINT [CK_Bookings_Amounts] CHECK ([PriceUSD] >= 0 AND [FeeUSD] >= 0)
);
GO
CREATE NONCLUSTERED INDEX [IX_Bookings_User] ON [Booking].[Bookings]([UserID], [StartDateTime] DESC) INCLUDE ([BookingStatusID], [CourtID]);
CREATE NONCLUSTERED INDEX [IX_Bookings_Court_Start] ON [Booking].[Bookings]([CourtID], [StartDateTime]) INCLUDE ([EndDateTime], [BookingStatusID]);
CREATE NONCLUSTERED INDEX [IX_Bookings_Pending_Expires] ON [Booking].[Bookings]([ExpiresAt]) WHERE [BookingStatusID] = 1;
GO

-- ===== Booking.BookingSlots (bloques de 30 min ocupados por reservas activas)
CREATE TABLE [Booking].[BookingSlots](
    [CourtID]    INT           NOT NULL,
    [SlotStart]  DATETIME2(0)  NOT NULL,
    [BookingID]  INT           NOT NULL,
    CONSTRAINT [PK_BookingSlots] PRIMARY KEY CLUSTERED ([CourtID], [SlotStart]),
    CONSTRAINT [FK_BookingSlots_Bookings] FOREIGN KEY ([BookingID]) REFERENCES [Booking].[Bookings]([BookingID]) ON DELETE CASCADE,
    CONSTRAINT [CK_BookingSlots_HalfHour] CHECK (DATEPART(MINUTE, [SlotStart]) IN (0, 30) AND DATEPART(SECOND, [SlotStart]) = 0)
);
GO
CREATE NONCLUSTERED INDEX [IX_BookingSlots_BookingID] ON [Booking].[BookingSlots]([BookingID]);
GO

-- ===== Booking.BookingStatusHistory
CREATE TABLE [Booking].[BookingStatusHistory](
    [BookingStatusHistoryID] INT IDENTITY(1,1) NOT NULL,
    [BookingID]              INT            NOT NULL,
    [FromStatusID]           INT            NULL,
    [ToStatusID]             INT            NOT NULL,
    [ChangedByUserID]        INT            NULL,   -- NULL = proceso automático
    [Notes]                  NVARCHAR(250)  NULL,
    [ChangeDate]             DATETIME2(0)   NOT NULL CONSTRAINT [DF_BookingStatusHistory_ChangeDate] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_BookingStatusHistory] PRIMARY KEY CLUSTERED ([BookingStatusHistoryID]),
    CONSTRAINT [FK_BookingStatusHistory_Bookings] FOREIGN KEY ([BookingID]) REFERENCES [Booking].[Bookings]([BookingID]),
    CONSTRAINT [FK_BookingStatusHistory_From] FOREIGN KEY ([FromStatusID]) REFERENCES [Booking].[BookingStatuses]([BookingStatusID]),
    CONSTRAINT [FK_BookingStatusHistory_To] FOREIGN KEY ([ToStatusID]) REFERENCES [Booking].[BookingStatuses]([BookingStatusID])
);
GO
CREATE NONCLUSTERED INDEX [IX_BookingStatusHistory_BookingID] ON [Booking].[BookingStatusHistory]([BookingID]);
GO
