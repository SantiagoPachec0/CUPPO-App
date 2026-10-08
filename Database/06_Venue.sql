USE [CUPPO];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================================
   06. COMPLEJOS Y CANCHAS (esquema [Venue])
   Verificación de dueños, complejos, canchas, horarios, precios y bloqueos.

   Convenciones de horario:
   - DayOfWeek: 1 = lunes ... 7 = domingo (ver [Catalog].[GetIsoDayOfWeek]).
   - Las horas son hora local de Venezuela.
   - EndTime = '00:00' significa medianoche (fin del día). No se manejan
     horarios que crucen la medianoche.
   - Las horas de inicio/fin van en múltiplos de 30 minutos.
   ============================================================================ */

IF SCHEMA_ID('Venue') IS NULL EXEC('CREATE SCHEMA [Venue]');
GO

-- ===== Venue.VerificationStatuses (dueños y complejos)
CREATE TABLE [Venue].[VerificationStatuses](
    [VerificationStatusID] INT         NOT NULL,
    [Code]                 VARCHAR(20) NOT NULL,
    [Name]                 VARCHAR(50) NOT NULL,
    CONSTRAINT [PK_VerificationStatuses] PRIMARY KEY CLUSTERED ([VerificationStatusID]),
    CONSTRAINT [UQ_VerificationStatuses_Code] UNIQUE ([Code])
);
GO

-- ===== Venue.OwnerProfiles
-- Solicitud y estado de verificación del dueño. Solo un perfil APPROVED
-- recibe el rol COMPLEX_ADMIN y con él el módulo "Panel de dueño".
CREATE TABLE [Venue].[OwnerProfiles](
    [UserID]               INT            NOT NULL,
    [DocumentType]         CHAR(1)        NOT NULL,   -- V, E, J, G, P
    [DocumentNumber]       VARCHAR(20)    NOT NULL,
    [LegalName]            NVARCHAR(150)  NOT NULL,
    [Phone]                VARCHAR(20)    NOT NULL,
    [DocumentUrl]          VARCHAR(500)   NULL,       -- foto de cédula / RIF
    [VerificationStatusID] INT            NOT NULL CONSTRAINT [DF_OwnerProfiles_VerificationStatusID] DEFAULT (1),
    [ReviewedByUserID]     INT            NULL,
    [ReviewedDate]         DATETIME2(0)   NULL,
    [ReviewNotes]          NVARCHAR(500)  NULL,
    [CreationDate]         DATETIME2(0)   NOT NULL CONSTRAINT [DF_OwnerProfiles_CreationDate] DEFAULT (SYSUTCDATETIME()),
    [UpdateDate]           DATETIME2(0)   NULL,
    CONSTRAINT [PK_OwnerProfiles] PRIMARY KEY CLUSTERED ([UserID]),
    CONSTRAINT [UQ_OwnerProfiles_Document] UNIQUE ([DocumentType], [DocumentNumber]),
    CONSTRAINT [FK_OwnerProfiles_Users] FOREIGN KEY ([UserID]) REFERENCES [Security].[Users]([UserID]),
    CONSTRAINT [FK_OwnerProfiles_ReviewedBy] FOREIGN KEY ([ReviewedByUserID]) REFERENCES [Security].[Users]([UserID]),
    CONSTRAINT [FK_OwnerProfiles_VerificationStatuses] FOREIGN KEY ([VerificationStatusID]) REFERENCES [Venue].[VerificationStatuses]([VerificationStatusID]),
    CONSTRAINT [CK_OwnerProfiles_DocumentType] CHECK ([DocumentType] IN ('V', 'E', 'J', 'G', 'P'))
);
GO

-- ===== Venue.Venues (complejo deportivo)
CREATE TABLE [Venue].[Venues](
    [VenueID]                 INT IDENTITY(1,1) NOT NULL,
    [OwnerUserID]             INT             NOT NULL,
    [Name]                    NVARCHAR(100)   NOT NULL,
    [Description]             NVARCHAR(1000)  NULL,
    [ZoneID]                  INT             NOT NULL,
    [Address]                 NVARCHAR(250)   NOT NULL,
    [Latitude]                DECIMAL(9,6)    NULL,
    [Longitude]               DECIMAL(9,6)    NULL,
    [Phone]                   VARCHAR(20)     NULL,
    [WhatsApp]                VARCHAR(20)     NULL,
    [Instagram]               VARCHAR(50)     NULL,
    [BookingHoldMinutes]      INT             NOT NULL CONSTRAINT [DF_Venues_BookingHoldMinutes] DEFAULT (30),
    [CancellationHours]       INT             NOT NULL CONSTRAINT [DF_Venues_CancellationHours] DEFAULT (24),
    [VerificationStatusID]    INT             NOT NULL CONSTRAINT [DF_Venues_VerificationStatusID] DEFAULT (1),
    [StatusID]                INT             NOT NULL CONSTRAINT [DF_Venues_StatusID] DEFAULT (1),
    [CreationUserID]          INT             NOT NULL,
    [UpdateUserID]            INT             NULL,
    [CreationDate]            DATETIME2(0)    NOT NULL CONSTRAINT [DF_Venues_CreationDate] DEFAULT (SYSUTCDATETIME()),
    [UpdateDate]              DATETIME2(0)    NULL,
    CONSTRAINT [PK_Venues] PRIMARY KEY CLUSTERED ([VenueID]),
    CONSTRAINT [FK_Venues_Owner] FOREIGN KEY ([OwnerUserID]) REFERENCES [Venue].[OwnerProfiles]([UserID]),
    CONSTRAINT [FK_Venues_Zones] FOREIGN KEY ([ZoneID]) REFERENCES [Catalog].[Zones]([ZoneID]),
    CONSTRAINT [FK_Venues_VerificationStatuses] FOREIGN KEY ([VerificationStatusID]) REFERENCES [Venue].[VerificationStatuses]([VerificationStatusID]),
    CONSTRAINT [FK_Venues_Statuses] FOREIGN KEY ([StatusID]) REFERENCES [Catalog].[Statuses]([StatusID]),
    CONSTRAINT [CK_Venues_Latitude] CHECK ([Latitude] BETWEEN -90 AND 90),
    CONSTRAINT [CK_Venues_Longitude] CHECK ([Longitude] BETWEEN -180 AND 180),
    CONSTRAINT [CK_Venues_BookingHoldMinutes] CHECK ([BookingHoldMinutes] BETWEEN 5 AND 1440),
    CONSTRAINT [CK_Venues_CancellationHours] CHECK ([CancellationHours] BETWEEN 0 AND 168)
);
GO
CREATE NONCLUSTERED INDEX [IX_Venues_OwnerUserID] ON [Venue].[Venues]([OwnerUserID]);
CREATE NONCLUSTERED INDEX [IX_Venues_ZoneID] ON [Venue].[Venues]([ZoneID]) INCLUDE ([Name], [VerificationStatusID], [StatusID]);
GO

-- ===== Venue.VenuePhotos
CREATE TABLE [Venue].[VenuePhotos](
    [VenuePhotoID]  INT IDENTITY(1,1) NOT NULL,
    [VenueID]       INT           NOT NULL,
    [Url]           VARCHAR(500)  NOT NULL,
    [IsCover]       BIT           NOT NULL CONSTRAINT [DF_VenuePhotos_IsCover] DEFAULT (0),
    [DisplayOrder]  INT           NOT NULL CONSTRAINT [DF_VenuePhotos_DisplayOrder] DEFAULT (0),
    [CreationDate]  DATETIME2(0)  NOT NULL CONSTRAINT [DF_VenuePhotos_CreationDate] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_VenuePhotos] PRIMARY KEY CLUSTERED ([VenuePhotoID]),
    CONSTRAINT [FK_VenuePhotos_Venues] FOREIGN KEY ([VenueID]) REFERENCES [Venue].[Venues]([VenueID]) ON DELETE CASCADE
);
GO
CREATE NONCLUSTERED INDEX [IX_VenuePhotos_VenueID] ON [Venue].[VenuePhotos]([VenueID]);
-- Solo una foto de portada por complejo
CREATE UNIQUE NONCLUSTERED INDEX [UX_VenuePhotos_Cover] ON [Venue].[VenuePhotos]([VenueID]) WHERE [IsCover] = 1;
GO

-- ===== Venue.VenueAmenities
CREATE TABLE [Venue].[VenueAmenities](
    [VenueID]    INT NOT NULL,
    [AmenityID]  INT NOT NULL,
    CONSTRAINT [PK_VenueAmenities] PRIMARY KEY CLUSTERED ([VenueID], [AmenityID]),
    CONSTRAINT [FK_VenueAmenities_Venues] FOREIGN KEY ([VenueID]) REFERENCES [Venue].[Venues]([VenueID]) ON DELETE CASCADE,
    CONSTRAINT [FK_VenueAmenities_Amenities] FOREIGN KEY ([AmenityID]) REFERENCES [Catalog].[Amenities]([AmenityID])
);
GO

-- ===== Venue.VenuePaymentAccounts (datos de cobro que ve el jugador al pagar)
CREATE TABLE [Venue].[VenuePaymentAccounts](
    [VenuePaymentAccountID] INT IDENTITY(1,1) NOT NULL,
    [VenueID]               INT            NOT NULL,
    [PaymentMethodID]       INT            NOT NULL,
    [BankName]              VARCHAR(80)    NULL,
    [AccountHolder]         NVARCHAR(150)  NULL,
    [DocumentNumber]        VARCHAR(20)    NULL,   -- cédula / RIF para Pago Móvil o transferencia
    [Phone]                 VARCHAR(20)    NULL,   -- Pago Móvil
    [AccountNumber]         VARCHAR(30)    NULL,   -- transferencia
    [Email]                 VARCHAR(100)   NULL,   -- Zelle / Binance
    [Notes]                 NVARCHAR(250)  NULL,
    [StatusID]              INT            NOT NULL CONSTRAINT [DF_VenuePaymentAccounts_StatusID] DEFAULT (1),
    [CreationUserID]        INT            NOT NULL,
    [UpdateUserID]          INT            NULL,
    [CreationDate]          DATETIME2(0)   NOT NULL CONSTRAINT [DF_VenuePaymentAccounts_CreationDate] DEFAULT (SYSUTCDATETIME()),
    [UpdateDate]            DATETIME2(0)   NULL,
    CONSTRAINT [PK_VenuePaymentAccounts] PRIMARY KEY CLUSTERED ([VenuePaymentAccountID]),
    CONSTRAINT [FK_VenuePaymentAccounts_Venues] FOREIGN KEY ([VenueID]) REFERENCES [Venue].[Venues]([VenueID]),
    CONSTRAINT [FK_VenuePaymentAccounts_PaymentMethods] FOREIGN KEY ([PaymentMethodID]) REFERENCES [Catalog].[PaymentMethods]([PaymentMethodID]),
    CONSTRAINT [FK_VenuePaymentAccounts_Statuses] FOREIGN KEY ([StatusID]) REFERENCES [Catalog].[Statuses]([StatusID])
);
GO
CREATE NONCLUSTERED INDEX [IX_VenuePaymentAccounts_VenueID] ON [Venue].[VenuePaymentAccounts]([VenueID]);
GO

-- ===== Venue.Courts (cancha)
-- SlotMinutes: duración mínima / bloque estándar de reserva de esta cancha.
CREATE TABLE [Venue].[Courts](
    [CourtID]          INT IDENTITY(1,1) NOT NULL,
    [VenueID]          INT            NOT NULL,
    [SportID]          INT            NOT NULL,
    [SurfaceID]        INT            NULL,
    [Name]             NVARCHAR(80)   NOT NULL,
    [Description]      NVARCHAR(500)  NULL,
    [IsCovered]        BIT            NOT NULL CONSTRAINT [DF_Courts_IsCovered] DEFAULT (0),
    [HasLighting]      BIT            NOT NULL CONSTRAINT [DF_Courts_HasLighting] DEFAULT (0),
    [PlayersCapacity]  INT            NULL,
    [SlotMinutes]      INT            NOT NULL CONSTRAINT [DF_Courts_SlotMinutes] DEFAULT (60),
    [StatusID]         INT            NOT NULL CONSTRAINT [DF_Courts_StatusID] DEFAULT (1),
    [CreationUserID]   INT            NOT NULL,
    [UpdateUserID]     INT            NULL,
    [CreationDate]     DATETIME2(0)   NOT NULL CONSTRAINT [DF_Courts_CreationDate] DEFAULT (SYSUTCDATETIME()),
    [UpdateDate]       DATETIME2(0)   NULL,
    CONSTRAINT [PK_Courts] PRIMARY KEY CLUSTERED ([CourtID]),
    CONSTRAINT [UQ_Courts_Venue_Name] UNIQUE ([VenueID], [Name]),
    CONSTRAINT [FK_Courts_Venues] FOREIGN KEY ([VenueID]) REFERENCES [Venue].[Venues]([VenueID]),
    CONSTRAINT [FK_Courts_Sports] FOREIGN KEY ([SportID]) REFERENCES [Catalog].[Sports]([SportID]),
    CONSTRAINT [FK_Courts_Surfaces] FOREIGN KEY ([SurfaceID]) REFERENCES [Catalog].[Surfaces]([SurfaceID]),
    CONSTRAINT [FK_Courts_Statuses] FOREIGN KEY ([StatusID]) REFERENCES [Catalog].[Statuses]([StatusID]),
    CONSTRAINT [CK_Courts_SlotMinutes] CHECK ([SlotMinutes] BETWEEN 30 AND 240 AND [SlotMinutes] % 30 = 0),
    CONSTRAINT [CK_Courts_PlayersCapacity] CHECK ([PlayersCapacity] IS NULL OR [PlayersCapacity] > 0)
);
GO
CREATE NONCLUSTERED INDEX [IX_Courts_SportID] ON [Venue].[Courts]([SportID]) INCLUDE ([VenueID], [StatusID]);
GO

-- ===== Venue.CourtPhotos
CREATE TABLE [Venue].[CourtPhotos](
    [CourtPhotoID]  INT IDENTITY(1,1) NOT NULL,
    [CourtID]       INT           NOT NULL,
    [Url]           VARCHAR(500)  NOT NULL,
    [DisplayOrder]  INT           NOT NULL CONSTRAINT [DF_CourtPhotos_DisplayOrder] DEFAULT (0),
    [CreationDate]  DATETIME2(0)  NOT NULL CONSTRAINT [DF_CourtPhotos_CreationDate] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_CourtPhotos] PRIMARY KEY CLUSTERED ([CourtPhotoID]),
    CONSTRAINT [FK_CourtPhotos_Courts] FOREIGN KEY ([CourtID]) REFERENCES [Venue].[Courts]([CourtID]) ON DELETE CASCADE
);
GO
CREATE NONCLUSTERED INDEX [IX_CourtPhotos_CourtID] ON [Venue].[CourtPhotos]([CourtID]);
GO

-- ===== Venue.CourtSchedules (horario de apertura por día de la semana)
-- Puede haber varias franjas el mismo día (ej. 07:00-12:00 y 14:00-00:00).
CREATE TABLE [Venue].[CourtSchedules](
    [CourtScheduleID] INT IDENTITY(1,1) NOT NULL,
    [CourtID]         INT      NOT NULL,
    [DayOfWeek]       TINYINT  NOT NULL,
    [OpenTime]        TIME(0)  NOT NULL,
    [CloseTime]       TIME(0)  NOT NULL,
    [StatusID]        INT      NOT NULL CONSTRAINT [DF_CourtSchedules_StatusID] DEFAULT (1),
    CONSTRAINT [PK_CourtSchedules] PRIMARY KEY CLUSTERED ([CourtScheduleID]),
    CONSTRAINT [FK_CourtSchedules_Courts] FOREIGN KEY ([CourtID]) REFERENCES [Venue].[Courts]([CourtID]) ON DELETE CASCADE,
    CONSTRAINT [FK_CourtSchedules_Statuses] FOREIGN KEY ([StatusID]) REFERENCES [Catalog].[Statuses]([StatusID]),
    CONSTRAINT [CK_CourtSchedules_DayOfWeek] CHECK ([DayOfWeek] BETWEEN 1 AND 7),
    CONSTRAINT [CK_CourtSchedules_Range] CHECK ([CloseTime] > [OpenTime] OR [CloseTime] = '00:00'),
    CONSTRAINT [CK_CourtSchedules_HalfHour] CHECK (DATEPART(MINUTE, [OpenTime]) IN (0, 30) AND DATEPART(MINUTE, [CloseTime]) IN (0, 30)
                                                  AND DATEPART(SECOND, [OpenTime]) = 0 AND DATEPART(SECOND, [CloseTime]) = 0)
);
GO
CREATE NONCLUSTERED INDEX [IX_CourtSchedules_Court_Day] ON [Venue].[CourtSchedules]([CourtID], [DayOfWeek]) INCLUDE ([OpenTime], [CloseTime], [StatusID]);
GO

-- ===== Venue.CourtPrices (precio por HORA en USD según franja)
-- DayOfWeek NULL = aplica a todos los días. Una franja con día específico
-- tiene prioridad sobre la general (ej. tarifa nocturna de fin de semana).
CREATE TABLE [Venue].[CourtPrices](
    [CourtPriceID]   INT IDENTITY(1,1) NOT NULL,
    [CourtID]        INT            NOT NULL,
    [DayOfWeek]      TINYINT        NULL,
    [StartTime]      TIME(0)        NOT NULL,
    [EndTime]        TIME(0)        NOT NULL,
    [PricePerHourUSD] DECIMAL(10,2) NOT NULL,
    [StatusID]       INT            NOT NULL CONSTRAINT [DF_CourtPrices_StatusID] DEFAULT (1),
    CONSTRAINT [PK_CourtPrices] PRIMARY KEY CLUSTERED ([CourtPriceID]),
    CONSTRAINT [FK_CourtPrices_Courts] FOREIGN KEY ([CourtID]) REFERENCES [Venue].[Courts]([CourtID]) ON DELETE CASCADE,
    CONSTRAINT [FK_CourtPrices_Statuses] FOREIGN KEY ([StatusID]) REFERENCES [Catalog].[Statuses]([StatusID]),
    CONSTRAINT [CK_CourtPrices_DayOfWeek] CHECK ([DayOfWeek] IS NULL OR [DayOfWeek] BETWEEN 1 AND 7),
    CONSTRAINT [CK_CourtPrices_Range] CHECK ([EndTime] > [StartTime] OR [EndTime] = '00:00'),
    CONSTRAINT [CK_CourtPrices_HalfHour] CHECK (DATEPART(MINUTE, [StartTime]) IN (0, 30) AND DATEPART(MINUTE, [EndTime]) IN (0, 30)
                                               AND DATEPART(SECOND, [StartTime]) = 0 AND DATEPART(SECOND, [EndTime]) = 0),
    CONSTRAINT [CK_CourtPrices_Price] CHECK ([PricePerHourUSD] >= 0)
);
GO
CREATE NONCLUSTERED INDEX [IX_CourtPrices_CourtID] ON [Venue].[CourtPrices]([CourtID]) INCLUDE ([DayOfWeek], [StartTime], [EndTime], [PricePerHourUSD], [StatusID]);
GO

-- ===== Venue.CourtBlocks (mantenimiento, eventos, reservas por fuera de la app)
CREATE TABLE [Venue].[CourtBlocks](
    [CourtBlockID]    INT IDENTITY(1,1) NOT NULL,
    [CourtID]         INT            NOT NULL,
    [StartDateTime]   DATETIME2(0)   NOT NULL,   -- hora local
    [EndDateTime]     DATETIME2(0)   NOT NULL,   -- hora local
    [Reason]          NVARCHAR(250)  NULL,
    [CreationUserID]  INT            NOT NULL,
    [CreationDate]    DATETIME2(0)   NOT NULL CONSTRAINT [DF_CourtBlocks_CreationDate] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_CourtBlocks] PRIMARY KEY CLUSTERED ([CourtBlockID]),
    CONSTRAINT [FK_CourtBlocks_Courts] FOREIGN KEY ([CourtID]) REFERENCES [Venue].[Courts]([CourtID]) ON DELETE CASCADE,
    CONSTRAINT [CK_CourtBlocks_Range] CHECK ([EndDateTime] > [StartDateTime])
);
GO
CREATE NONCLUSTERED INDEX [IX_CourtBlocks_Court_Start] ON [Venue].[CourtBlocks]([CourtID], [StartDateTime]) INCLUDE ([EndDateTime]);
GO
