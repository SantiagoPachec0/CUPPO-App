USE [CUPPO];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================================
   05. CATÁLOGOS (esquema [Catalog])
   Estados genéricos, deportes, superficies, ubicación, comodidades,
   métodos de pago, tasas de cambio y parámetros del sistema.
   ============================================================================ */

IF SCHEMA_ID('Catalog') IS NULL EXEC('CREATE SCHEMA [Catalog]');
GO

-- ===== Catalog.Statuses (valores de StatusID usados en todas las tablas)
CREATE TABLE [Catalog].[Statuses](
    [StatusID]      INT          NOT NULL,
    [Code]          VARCHAR(20)  NOT NULL,
    [Name]          VARCHAR(50)  NOT NULL,
    CONSTRAINT [PK_Statuses] PRIMARY KEY CLUSTERED ([StatusID]),
    CONSTRAINT [UQ_Statuses_Code] UNIQUE ([Code])
);
GO

-- ===== Catalog.Sports
CREATE TABLE [Catalog].[Sports](
    [SportID]            INT IDENTITY(1,1) NOT NULL,
    [Code]               VARCHAR(20)   NOT NULL,
    [Name]               VARCHAR(50)   NOT NULL,
    [Icon]               VARCHAR(50)   NULL,
    [DefaultSlotMinutes] INT           NOT NULL CONSTRAINT [DF_Sports_DefaultSlotMinutes] DEFAULT (60),
    [DisplayOrder]       INT           NOT NULL CONSTRAINT [DF_Sports_DisplayOrder] DEFAULT (0),
    [StatusID]           INT           NOT NULL CONSTRAINT [DF_Sports_StatusID] DEFAULT (1),
    CONSTRAINT [PK_Sports] PRIMARY KEY CLUSTERED ([SportID]),
    CONSTRAINT [UQ_Sports_Code] UNIQUE ([Code]),
    CONSTRAINT [FK_Sports_Statuses] FOREIGN KEY ([StatusID]) REFERENCES [Catalog].[Statuses]([StatusID]),
    CONSTRAINT [CK_Sports_DefaultSlotMinutes] CHECK ([DefaultSlotMinutes] > 0 AND [DefaultSlotMinutes] % 30 = 0)
);
GO

-- ===== Catalog.Surfaces
CREATE TABLE [Catalog].[Surfaces](
    [SurfaceID]    INT IDENTITY(1,1) NOT NULL,
    [Code]         VARCHAR(20)  NOT NULL,
    [Name]         VARCHAR(50)  NOT NULL,
    [StatusID]     INT          NOT NULL CONSTRAINT [DF_Surfaces_StatusID] DEFAULT (1),
    CONSTRAINT [PK_Surfaces] PRIMARY KEY CLUSTERED ([SurfaceID]),
    CONSTRAINT [UQ_Surfaces_Code] UNIQUE ([Code]),
    CONSTRAINT [FK_Surfaces_Statuses] FOREIGN KEY ([StatusID]) REFERENCES [Catalog].[Statuses]([StatusID])
);
GO

-- ===== Catalog.States / Cities / Zones (Estado → Ciudad → Zona/Urbanización)
CREATE TABLE [Catalog].[States](
    [StateID]   INT IDENTITY(1,1) NOT NULL,
    [Name]      VARCHAR(50) NOT NULL,
    [StatusID]  INT         NOT NULL CONSTRAINT [DF_States_StatusID] DEFAULT (1),
    CONSTRAINT [PK_States] PRIMARY KEY CLUSTERED ([StateID]),
    CONSTRAINT [UQ_States_Name] UNIQUE ([Name]),
    CONSTRAINT [FK_States_Statuses] FOREIGN KEY ([StatusID]) REFERENCES [Catalog].[Statuses]([StatusID])
);
GO

CREATE TABLE [Catalog].[Cities](
    [CityID]    INT IDENTITY(1,1) NOT NULL,
    [StateID]   INT         NOT NULL,
    [Name]      VARCHAR(80) NOT NULL,
    [StatusID]  INT         NOT NULL CONSTRAINT [DF_Cities_StatusID] DEFAULT (1),
    CONSTRAINT [PK_Cities] PRIMARY KEY CLUSTERED ([CityID]),
    CONSTRAINT [UQ_Cities_State_Name] UNIQUE ([StateID], [Name]),
    CONSTRAINT [FK_Cities_States] FOREIGN KEY ([StateID]) REFERENCES [Catalog].[States]([StateID]),
    CONSTRAINT [FK_Cities_Statuses] FOREIGN KEY ([StatusID]) REFERENCES [Catalog].[Statuses]([StatusID])
);
GO

CREATE TABLE [Catalog].[Zones](
    [ZoneID]    INT IDENTITY(1,1) NOT NULL,
    [CityID]    INT         NOT NULL,
    [Name]      VARCHAR(80) NOT NULL,
    [StatusID]  INT         NOT NULL CONSTRAINT [DF_Zones_StatusID] DEFAULT (1),
    CONSTRAINT [PK_Zones] PRIMARY KEY CLUSTERED ([ZoneID]),
    CONSTRAINT [UQ_Zones_City_Name] UNIQUE ([CityID], [Name]),
    CONSTRAINT [FK_Zones_Cities] FOREIGN KEY ([CityID]) REFERENCES [Catalog].[Cities]([CityID]),
    CONSTRAINT [FK_Zones_Statuses] FOREIGN KEY ([StatusID]) REFERENCES [Catalog].[Statuses]([StatusID])
);
GO

-- ===== Catalog.Amenities (estacionamiento, vestuarios, iluminación...)
CREATE TABLE [Catalog].[Amenities](
    [AmenityID]  INT IDENTITY(1,1) NOT NULL,
    [Code]       VARCHAR(20) NOT NULL,
    [Name]       VARCHAR(50) NOT NULL,
    [Icon]       VARCHAR(50) NULL,
    [StatusID]   INT         NOT NULL CONSTRAINT [DF_Amenities_StatusID] DEFAULT (1),
    CONSTRAINT [PK_Amenities] PRIMARY KEY CLUSTERED ([AmenityID]),
    CONSTRAINT [UQ_Amenities_Code] UNIQUE ([Code]),
    CONSTRAINT [FK_Amenities_Statuses] FOREIGN KEY ([StatusID]) REFERENCES [Catalog].[Statuses]([StatusID])
);
GO

-- ===== Catalog.PaymentMethods
-- Currency: moneda en la que se recibe el pago (USD, VES o USDT).
CREATE TABLE [Catalog].[PaymentMethods](
    [PaymentMethodID]   INT IDENTITY(1,1) NOT NULL,
    [Code]              VARCHAR(20) NOT NULL,
    [Name]              VARCHAR(50) NOT NULL,
    [Currency]          CHAR(4)     NOT NULL,
    [RequiresReference] BIT         NOT NULL CONSTRAINT [DF_PaymentMethods_RequiresReference] DEFAULT (1),
    [IsOnline]          BIT         NOT NULL CONSTRAINT [DF_PaymentMethods_IsOnline] DEFAULT (1),
    [DisplayOrder]      INT         NOT NULL CONSTRAINT [DF_PaymentMethods_DisplayOrder] DEFAULT (0),
    [StatusID]          INT         NOT NULL CONSTRAINT [DF_PaymentMethods_StatusID] DEFAULT (1),
    CONSTRAINT [PK_PaymentMethods] PRIMARY KEY CLUSTERED ([PaymentMethodID]),
    CONSTRAINT [UQ_PaymentMethods_Code] UNIQUE ([Code]),
    CONSTRAINT [FK_PaymentMethods_Statuses] FOREIGN KEY ([StatusID]) REFERENCES [Catalog].[Statuses]([StatusID]),
    CONSTRAINT [CK_PaymentMethods_Currency] CHECK ([Currency] IN ('USD', 'VES', 'USDT'))
);
GO

-- ===== Catalog.ExchangeRates (tasa oficial BCV: cuántos VES vale 1 USD en una fecha)
CREATE TABLE [Catalog].[ExchangeRates](
    [ExchangeRateID]  INT IDENTITY(1,1) NOT NULL,
    [RateDate]        DATE          NOT NULL,
    [Currency]        CHAR(4)       NOT NULL CONSTRAINT [DF_ExchangeRates_Currency] DEFAULT ('VES'),
    [RatePerUSD]      DECIMAL(18,4) NOT NULL,
    [Source]          VARCHAR(20)   NOT NULL CONSTRAINT [DF_ExchangeRates_Source] DEFAULT ('BCV'),
    [CreationDate]    DATETIME2(0)  NOT NULL CONSTRAINT [DF_ExchangeRates_CreationDate] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_ExchangeRates] PRIMARY KEY CLUSTERED ([ExchangeRateID]),
    CONSTRAINT [UQ_ExchangeRates_Date_Currency_Source] UNIQUE ([RateDate], [Currency], [Source]),
    CONSTRAINT [CK_ExchangeRates_RatePerUSD] CHECK ([RatePerUSD] > 0)
);
GO

-- ===== Catalog.Settings (parámetros del negocio editables sin desplegar código)
CREATE TABLE [Catalog].[Settings](
    [SettingKey]    VARCHAR(50)   NOT NULL,
    [SettingValue]  VARCHAR(500)  NOT NULL,
    [Description]   VARCHAR(250)  NULL,
    [UpdateUserID]  INT           NULL,
    [UpdateDate]    DATETIME2(0)  NULL,
    CONSTRAINT [PK_Settings] PRIMARY KEY CLUSTERED ([SettingKey])
);
GO

-- ===== Hora local de Venezuela (el servidor de producción puede estar en UTC)
CREATE OR ALTER FUNCTION [Catalog].[GetLocalDateTime]()
RETURNS DATETIME2(0)
AS
BEGIN
    RETURN CAST(SYSDATETIMEOFFSET() AT TIME ZONE 'Venezuela Standard Time' AS DATETIME2(0));
END;
GO

-- ===== Día de la semana ISO (1 = lunes ... 7 = domingo), sin depender de SET DATEFIRST
CREATE OR ALTER FUNCTION [Catalog].[GetIsoDayOfWeek](@Date DATE)
RETURNS TINYINT
AS
BEGIN
    -- 1900-01-01 fue lunes
    RETURN CAST((DATEDIFF(DAY, '19000101', @Date) % 7) + 1 AS TINYINT);
END;
GO
