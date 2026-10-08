USE [CUPPO];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================================
   08. PAGOS (esquema [Payment])
   Pagos manuales: el jugador paga por Pago Móvil, Zelle, etc. a la cuenta
   del complejo y sube la referencia y el comprobante; el dueño lo verifica.
   ============================================================================ */

IF SCHEMA_ID('Payment') IS NULL EXEC('CREATE SCHEMA [Payment]');
GO

-- ===== Payment.PaymentStatuses
CREATE TABLE [Payment].[PaymentStatuses](
    [PaymentStatusID] INT         NOT NULL,
    [Code]            VARCHAR(20) NOT NULL,
    [Name]            VARCHAR(50) NOT NULL,
    CONSTRAINT [PK_PaymentStatuses] PRIMARY KEY CLUSTERED ([PaymentStatusID]),
    CONSTRAINT [UQ_PaymentStatuses_Code] UNIQUE ([Code])
);
GO

-- ===== Payment.Payments
-- AmountPaid está en la moneda del método (Currency). AmountUSD es el
-- equivalente usando la tasa BCV del día (ExchangeRate) cuando aplica.
CREATE TABLE [Payment].[Payments](
    [PaymentID]              INT IDENTITY(1,1) NOT NULL,
    [BookingID]              INT            NOT NULL,
    [PaymentMethodID]        INT            NOT NULL,
    [VenuePaymentAccountID]  INT            NULL,       -- NULL = efectivo en el complejo
    [AmountPaid]             DECIMAL(14,2)  NOT NULL,
    [Currency]               CHAR(4)        NOT NULL,
    [ExchangeRate]           DECIMAL(18,4)  NULL,
    [AmountUSD]              DECIMAL(10,2)  NOT NULL,
    [Reference]              VARCHAR(50)    NULL,
    [ReceiptUrl]             VARCHAR(500)   NULL,
    [PayerName]              NVARCHAR(150)  NULL,
    [PayerDocument]          VARCHAR(20)    NULL,
    [PayerPhone]             VARCHAR(20)    NULL,
    [PaymentDate]            DATE           NOT NULL,   -- fecha que indica el jugador
    [PaymentStatusID]        INT            NOT NULL CONSTRAINT [DF_Payments_PaymentStatusID] DEFAULT (1),
    [ReviewedByUserID]       INT            NULL,
    [ReviewedDate]           DATETIME2(0)   NULL,
    [RejectionReason]        NVARCHAR(250)  NULL,
    [CreationUserID]         INT            NOT NULL,
    [CreationDate]           DATETIME2(0)   NOT NULL CONSTRAINT [DF_Payments_CreationDate] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_Payments] PRIMARY KEY CLUSTERED ([PaymentID]),
    CONSTRAINT [FK_Payments_Bookings] FOREIGN KEY ([BookingID]) REFERENCES [Booking].[Bookings]([BookingID]),
    CONSTRAINT [FK_Payments_PaymentMethods] FOREIGN KEY ([PaymentMethodID]) REFERENCES [Catalog].[PaymentMethods]([PaymentMethodID]),
    CONSTRAINT [FK_Payments_VenuePaymentAccounts] FOREIGN KEY ([VenuePaymentAccountID]) REFERENCES [Venue].[VenuePaymentAccounts]([VenuePaymentAccountID]),
    CONSTRAINT [FK_Payments_PaymentStatuses] FOREIGN KEY ([PaymentStatusID]) REFERENCES [Payment].[PaymentStatuses]([PaymentStatusID]),
    CONSTRAINT [FK_Payments_ReviewedBy] FOREIGN KEY ([ReviewedByUserID]) REFERENCES [Security].[Users]([UserID]),
    CONSTRAINT [FK_Payments_CreationUser] FOREIGN KEY ([CreationUserID]) REFERENCES [Security].[Users]([UserID]),
    CONSTRAINT [CK_Payments_Currency] CHECK ([Currency] IN ('USD', 'VES', 'USDT')),
    CONSTRAINT [CK_Payments_Amounts] CHECK ([AmountPaid] > 0 AND [AmountUSD] >= 0)
);
GO
CREATE NONCLUSTERED INDEX [IX_Payments_BookingID] ON [Payment].[Payments]([BookingID]);
CREATE NONCLUSTERED INDEX [IX_Payments_Status] ON [Payment].[Payments]([PaymentStatusID]) INCLUDE ([BookingID]);
-- Evita que se use la misma referencia dos veces en la misma cuenta (comprobante reciclado)
CREATE UNIQUE NONCLUSTERED INDEX [UX_Payments_Account_Reference] ON [Payment].[Payments]([VenuePaymentAccountID], [Reference])
    WHERE [Reference] IS NOT NULL AND [VenuePaymentAccountID] IS NOT NULL AND [PaymentStatusID] <> 3;
GO

/* ============================================================================
   NEGOCIO CUPPO (esquema [Billing]): planes y suscripciones de los complejos
   ============================================================================ */

IF SCHEMA_ID('Billing') IS NULL EXEC('CREATE SCHEMA [Billing]');
GO

CREATE TABLE [Billing].[SubscriptionPlans](
    [SubscriptionPlanID] INT IDENTITY(1,1) NOT NULL,
    [Code]               VARCHAR(20)    NOT NULL,
    [Name]               VARCHAR(50)    NOT NULL,
    [Description]        NVARCHAR(250)  NULL,
    [MonthlyPriceUSD]    DECIMAL(10,2)  NOT NULL,
    [DurationDays]       INT            NOT NULL,
    [MaxCourts]          INT            NULL,       -- NULL = ilimitado
    [IsTrial]            BIT            NOT NULL CONSTRAINT [DF_SubscriptionPlans_IsTrial] DEFAULT (0),
    [StatusID]           INT            NOT NULL CONSTRAINT [DF_SubscriptionPlans_StatusID] DEFAULT (1),
    CONSTRAINT [PK_SubscriptionPlans] PRIMARY KEY CLUSTERED ([SubscriptionPlanID]),
    CONSTRAINT [UQ_SubscriptionPlans_Code] UNIQUE ([Code]),
    CONSTRAINT [FK_SubscriptionPlans_Statuses] FOREIGN KEY ([StatusID]) REFERENCES [Catalog].[Statuses]([StatusID]),
    CONSTRAINT [CK_SubscriptionPlans_Values] CHECK ([MonthlyPriceUSD] >= 0 AND [DurationDays] > 0)
);
GO

CREATE TABLE [Billing].[VenueSubscriptions](
    [VenueSubscriptionID] INT IDENTITY(1,1) NOT NULL,
    [VenueID]             INT            NOT NULL,
    [SubscriptionPlanID]  INT            NOT NULL,
    [StartDate]           DATE           NOT NULL,
    [EndDate]             DATE           NOT NULL,
    [AmountPaidUSD]       DECIMAL(10,2)  NOT NULL CONSTRAINT [DF_VenueSubscriptions_AmountPaidUSD] DEFAULT (0),
    [PaymentReference]    VARCHAR(50)    NULL,
    [Notes]               NVARCHAR(250)  NULL,
    [CreationUserID]      INT            NOT NULL,
    [CreationDate]        DATETIME2(0)   NOT NULL CONSTRAINT [DF_VenueSubscriptions_CreationDate] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_VenueSubscriptions] PRIMARY KEY CLUSTERED ([VenueSubscriptionID]),
    CONSTRAINT [FK_VenueSubscriptions_Venues] FOREIGN KEY ([VenueID]) REFERENCES [Venue].[Venues]([VenueID]),
    CONSTRAINT [FK_VenueSubscriptions_Plans] FOREIGN KEY ([SubscriptionPlanID]) REFERENCES [Billing].[SubscriptionPlans]([SubscriptionPlanID]),
    CONSTRAINT [CK_VenueSubscriptions_Range] CHECK ([EndDate] >= [StartDate])
);
GO
CREATE NONCLUSTERED INDEX [IX_VenueSubscriptions_Venue_End] ON [Billing].[VenueSubscriptions]([VenueID], [EndDate] DESC);
GO

/* ============================================================================
   SOCIAL (esquema [Social]): reseñas y favoritos
   ============================================================================ */

IF SCHEMA_ID('Social') IS NULL EXEC('CREATE SCHEMA [Social]');
GO

-- Una reseña por reserva completada.
CREATE TABLE [Social].[Reviews](
    [ReviewID]      INT IDENTITY(1,1) NOT NULL,
    [BookingID]     INT             NOT NULL,
    [UserID]        INT             NOT NULL,
    [VenueID]       INT             NOT NULL,
    [Rating]        TINYINT         NOT NULL,
    [Comment]       NVARCHAR(1000)  NULL,
    [OwnerReply]    NVARCHAR(1000)  NULL,
    [StatusID]      INT             NOT NULL CONSTRAINT [DF_Reviews_StatusID] DEFAULT (1),
    [CreationDate]  DATETIME2(0)    NOT NULL CONSTRAINT [DF_Reviews_CreationDate] DEFAULT (SYSUTCDATETIME()),
    [UpdateDate]    DATETIME2(0)    NULL,
    CONSTRAINT [PK_Reviews] PRIMARY KEY CLUSTERED ([ReviewID]),
    CONSTRAINT [UQ_Reviews_BookingID] UNIQUE ([BookingID]),
    CONSTRAINT [FK_Reviews_Bookings] FOREIGN KEY ([BookingID]) REFERENCES [Booking].[Bookings]([BookingID]),
    CONSTRAINT [FK_Reviews_Users] FOREIGN KEY ([UserID]) REFERENCES [Security].[Users]([UserID]),
    CONSTRAINT [FK_Reviews_Venues] FOREIGN KEY ([VenueID]) REFERENCES [Venue].[Venues]([VenueID]),
    CONSTRAINT [FK_Reviews_Statuses] FOREIGN KEY ([StatusID]) REFERENCES [Catalog].[Statuses]([StatusID]),
    CONSTRAINT [CK_Reviews_Rating] CHECK ([Rating] BETWEEN 1 AND 5)
);
GO
CREATE NONCLUSTERED INDEX [IX_Reviews_VenueID] ON [Social].[Reviews]([VenueID]) INCLUDE ([Rating], [StatusID]);
GO

CREATE TABLE [Social].[Favorites](
    [UserID]        INT           NOT NULL,
    [VenueID]       INT           NOT NULL,
    [CreationDate]  DATETIME2(0)  NOT NULL CONSTRAINT [DF_Favorites_CreationDate] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_Favorites] PRIMARY KEY CLUSTERED ([UserID], [VenueID]),
    CONSTRAINT [FK_Favorites_Users] FOREIGN KEY ([UserID]) REFERENCES [Security].[Users]([UserID]),
    CONSTRAINT [FK_Favorites_Venues] FOREIGN KEY ([VenueID]) REFERENCES [Venue].[Venues]([VenueID]) ON DELETE CASCADE
);
GO

/* ============================================================================
   NOTIFICACIONES (esquema [Notification])
   ============================================================================ */

IF SCHEMA_ID('Notification') IS NULL EXEC('CREATE SCHEMA [Notification]');
GO

CREATE TABLE [Notification].[Notifications](
    [NotificationID]  INT IDENTITY(1,1) NOT NULL,
    [UserID]          INT             NOT NULL,
    [Type]            VARCHAR(30)     NOT NULL,   -- BOOKING_CONFIRMED, PAYMENT_REJECTED...
    [Title]           NVARCHAR(100)   NOT NULL,
    [Body]            NVARCHAR(500)   NOT NULL,
    [DataJson]        NVARCHAR(1000)  NULL,       -- ej. {"bookingId": 15}
    [IsRead]          BIT             NOT NULL CONSTRAINT [DF_Notifications_IsRead] DEFAULT (0),
    [SentPush]        BIT             NOT NULL CONSTRAINT [DF_Notifications_SentPush] DEFAULT (0),
    [CreationDate]    DATETIME2(0)    NOT NULL CONSTRAINT [DF_Notifications_CreationDate] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_Notifications] PRIMARY KEY CLUSTERED ([NotificationID]),
    CONSTRAINT [FK_Notifications_Users] FOREIGN KEY ([UserID]) REFERENCES [Security].[Users]([UserID])
);
GO
CREATE NONCLUSTERED INDEX [IX_Notifications_User] ON [Notification].[Notifications]([UserID], [CreationDate] DESC) INCLUDE ([IsRead]);
GO

CREATE TABLE [Notification].[DeviceTokens](
    [DeviceTokenID]  INT IDENTITY(1,1) NOT NULL,
    [UserID]         INT           NOT NULL,
    [Token]          VARCHAR(500)  NOT NULL,   -- token de Firebase Cloud Messaging
    [Platform]       VARCHAR(10)   NOT NULL,
    [LastSeenDate]   DATETIME2(0)  NOT NULL CONSTRAINT [DF_DeviceTokens_LastSeenDate] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_DeviceTokens] PRIMARY KEY CLUSTERED ([DeviceTokenID]),
    CONSTRAINT [FK_DeviceTokens_Users] FOREIGN KEY ([UserID]) REFERENCES [Security].[Users]([UserID]),
    CONSTRAINT [CK_DeviceTokens_Platform] CHECK ([Platform] IN ('ANDROID', 'IOS'))
);
GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_DeviceTokens_Token] ON [Notification].[DeviceTokens]([Token]);
CREATE NONCLUSTERED INDEX [IX_DeviceTokens_UserID] ON [Notification].[DeviceTokens]([UserID]);
GO
