USE [CUPPO];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================================
   15. BÚSQUEDA PÚBLICA DE COMPLEJOS Y FICHA (Fase 2)

   Un complejo es público si: está aprobado y activo, su dueño está verificado
   y tiene al menos una cancha activa con horario.
   ============================================================================ */

-- ===== Venue.IsPublicVenue
CREATE OR ALTER FUNCTION [Venue].[IsPublicVenue](@VenueID INT)
RETURNS BIT
AS
BEGIN
    RETURN CASE WHEN EXISTS (
        SELECT 1
        FROM [Venue].[Venues] V
        INNER JOIN [Venue].[OwnerProfiles] OP ON OP.[UserID] = V.[OwnerUserID]
        WHERE V.[VenueID] = @VenueID
          AND V.[StatusID] = 1
          AND V.[VerificationStatusID] = 2
          AND OP.[VerificationStatusID] = 2
          AND EXISTS (SELECT 1 FROM [Venue].[Courts] C
                      WHERE C.[VenueID] = V.[VenueID] AND C.[StatusID] = 1
                        AND EXISTS (SELECT 1 FROM [Venue].[CourtSchedules] CS WHERE CS.[CourtID] = C.[CourtID] AND CS.[StatusID] = 1))
    ) THEN 1 ELSE 0 END;
END;
GO

-- ===== Venue.SearchVenues
-- Filtros opcionales. Con @Latitude/@Longitude ordena por distancia (km);
-- si no, por calificación y nombre. Paginado; TotalCount viene en cada fila.
CREATE OR ALTER PROCEDURE [Venue].[SearchVenues]
    @SportID INT = NULL,
    @CityID INT = NULL,
    @ZoneID INT = NULL,
    @Search NVARCHAR(100) = NULL,
    @Latitude DECIMAL(9,6) = NULL,
    @Longitude DECIMAL(9,6) = NULL,
    @Page INT = 1,
    @PageSize INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    SET @Page = CASE WHEN @Page IS NULL OR @Page < 1 THEN 1 ELSE @Page END;
    SET @PageSize = CASE WHEN @PageSize IS NULL OR @PageSize < 1 THEN 20 WHEN @PageSize > 50 THEN 50 ELSE @PageSize END;
    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), N'');

    WITH Candidates AS (
        SELECT V.[VenueID], V.[Name], V.[Address], V.[Latitude], V.[Longitude],
               Z.[ZoneID], Z.[Name] AS [ZoneName], CI.[CityID], CI.[Name] AS [CityName],
               CASE WHEN @Latitude IS NOT NULL AND @Longitude IS NOT NULL AND V.[Latitude] IS NOT NULL AND V.[Longitude] IS NOT NULL
                    THEN 6371.0 * 2 * ASIN(SQRT(
                           POWER(SIN(RADIANS(CAST(V.[Latitude] AS FLOAT) - CAST(@Latitude AS FLOAT)) / 2), 2)
                         + COS(RADIANS(CAST(@Latitude AS FLOAT))) * COS(RADIANS(CAST(V.[Latitude] AS FLOAT)))
                         * POWER(SIN(RADIANS(CAST(V.[Longitude] AS FLOAT) - CAST(@Longitude AS FLOAT)) / 2), 2)))
               END AS [DistanceKm]
        FROM [Venue].[Venues] V
        INNER JOIN [Catalog].[Zones] Z ON Z.[ZoneID] = V.[ZoneID]
        INNER JOIN [Catalog].[Cities] CI ON CI.[CityID] = Z.[CityID]
        INNER JOIN [Venue].[OwnerProfiles] OP ON OP.[UserID] = V.[OwnerUserID]
        WHERE V.[StatusID] = 1
          AND V.[VerificationStatusID] = 2
          AND OP.[VerificationStatusID] = 2
          AND (@ZoneID IS NULL OR V.[ZoneID] = @ZoneID)
          AND (@CityID IS NULL OR Z.[CityID] = @CityID)
          AND (@Search IS NULL OR V.[Name] LIKE N'%' + @Search + N'%' OR Z.[Name] LIKE N'%' + @Search + N'%')
          AND EXISTS (SELECT 1 FROM [Venue].[Courts] C
                      WHERE C.[VenueID] = V.[VenueID] AND C.[StatusID] = 1
                        AND (@SportID IS NULL OR C.[SportID] = @SportID)
                        AND EXISTS (SELECT 1 FROM [Venue].[CourtSchedules] CS WHERE CS.[CourtID] = C.[CourtID] AND CS.[StatusID] = 1))
    ),
    Ranked AS (
        SELECT C.*,
               R.[AvgRating], ISNULL(R.[ReviewCount], 0) AS [ReviewCount],
               COUNT(*) OVER () AS [TotalCount]
        FROM Candidates C
        OUTER APPLY (SELECT CAST(AVG(CAST(RV.[Rating] AS DECIMAL(4,2))) AS DECIMAL(3,2)) AS [AvgRating], COUNT(*) AS [ReviewCount]
                     FROM [Social].[Reviews] RV WHERE RV.[VenueID] = C.[VenueID] AND RV.[StatusID] = 1) R
    )
    SELECT R.[VenueID], R.[Name], R.[Address], R.[ZoneID], R.[ZoneName], R.[CityID], R.[CityName],
           R.[Latitude], R.[Longitude], CAST(R.[DistanceKm] AS DECIMAL(8,2)) AS [DistanceKm],
           R.[AvgRating], R.[ReviewCount], R.[TotalCount],
           (SELECT TOP (1) P.[Url] FROM [Venue].[VenuePhotos] P WHERE P.[VenueID] = R.[VenueID] ORDER BY P.[IsCover] DESC, P.[DisplayOrder]) AS [CoverUrl],
           (SELECT MIN(CP.[PricePerHourUSD]) FROM [Venue].[CourtPrices] CP
            INNER JOIN [Venue].[Courts] C ON C.[CourtID] = CP.[CourtID]
            WHERE C.[VenueID] = R.[VenueID] AND C.[StatusID] = 1 AND CP.[StatusID] = 1
              AND (@SportID IS NULL OR C.[SportID] = @SportID)) AS [MinPricePerHourUSD],
           STUFF((SELECT DISTINCT N', ' + S.[Name]
                  FROM [Venue].[Courts] C INNER JOIN [Catalog].[Sports] S ON S.[SportID] = C.[SportID]
                  WHERE C.[VenueID] = R.[VenueID] AND C.[StatusID] = 1
                  FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(500)'), 1, 2, N'') AS [Sports]
    FROM Ranked R
    ORDER BY CASE WHEN R.[DistanceKm] IS NULL THEN 1 ELSE 0 END, R.[DistanceKm],
             R.[AvgRating] DESC, R.[Name]
    OFFSET (@Page - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- ===== Venue.GetPublicVenue: ficha pública
-- Result sets: 1 complejo, 2 fotos, 3 comodidades, 4 canchas, 5 fotos de canchas, 6 métodos de pago aceptados.
-- No devuelve filas si el complejo no es público. Los datos de las cuentas de cobro
-- no se muestran aquí: se entregan al pagar una reserva.
CREATE OR ALTER PROCEDURE [Venue].[GetPublicVenue]
    @VenueID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsPublic BIT = [Venue].[IsPublicVenue](@VenueID);

    SELECT V.[VenueID], V.[Name], V.[Description], V.[Address], V.[Latitude], V.[Longitude],
           Z.[ZoneID], Z.[Name] AS [ZoneName], CI.[CityID], CI.[Name] AS [CityName],
           V.[Phone], V.[WhatsApp], V.[Instagram], V.[CancellationHours],
           R.[AvgRating], ISNULL(R.[ReviewCount], 0) AS [ReviewCount]
    FROM [Venue].[Venues] V
    INNER JOIN [Catalog].[Zones] Z ON Z.[ZoneID] = V.[ZoneID]
    INNER JOIN [Catalog].[Cities] CI ON CI.[CityID] = Z.[CityID]
    OUTER APPLY (SELECT CAST(AVG(CAST(RV.[Rating] AS DECIMAL(4,2))) AS DECIMAL(3,2)) AS [AvgRating], COUNT(*) AS [ReviewCount]
                 FROM [Social].[Reviews] RV WHERE RV.[VenueID] = V.[VenueID] AND RV.[StatusID] = 1) R
    WHERE V.[VenueID] = @VenueID AND @IsPublic = 1;

    SELECT [VenuePhotoID], [Url], [IsCover], [DisplayOrder]
    FROM [Venue].[VenuePhotos]
    WHERE [VenueID] = @VenueID AND @IsPublic = 1
    ORDER BY [IsCover] DESC, [DisplayOrder], [VenuePhotoID];

    SELECT A.[AmenityID], A.[Code], A.[Name], A.[Icon]
    FROM [Venue].[VenueAmenities] VA
    INNER JOIN [Catalog].[Amenities] A ON A.[AmenityID] = VA.[AmenityID]
    WHERE VA.[VenueID] = @VenueID AND A.[StatusID] = 1 AND @IsPublic = 1
    ORDER BY A.[Name];

    SELECT C.[CourtID], C.[Name], C.[Description], C.[SportID], S.[Code] AS [SportCode], S.[Name] AS [SportName],
           C.[SurfaceID], SU.[Name] AS [SurfaceName], C.[IsCovered], C.[HasLighting], C.[PlayersCapacity], C.[SlotMinutes],
           (SELECT MIN(CP.[PricePerHourUSD]) FROM [Venue].[CourtPrices] CP WHERE CP.[CourtID] = C.[CourtID] AND CP.[StatusID] = 1) AS [MinPricePerHourUSD],
           (SELECT MAX(CP.[PricePerHourUSD]) FROM [Venue].[CourtPrices] CP WHERE CP.[CourtID] = C.[CourtID] AND CP.[StatusID] = 1) AS [MaxPricePerHourUSD]
    FROM [Venue].[Courts] C
    INNER JOIN [Catalog].[Sports] S ON S.[SportID] = C.[SportID]
    LEFT JOIN [Catalog].[Surfaces] SU ON SU.[SurfaceID] = C.[SurfaceID]
    WHERE C.[VenueID] = @VenueID AND C.[StatusID] = 1 AND @IsPublic = 1
      AND EXISTS (SELECT 1 FROM [Venue].[CourtSchedules] CS WHERE CS.[CourtID] = C.[CourtID] AND CS.[StatusID] = 1)
    ORDER BY S.[DisplayOrder], C.[Name];

    SELECT CPH.[CourtPhotoID], CPH.[CourtID], CPH.[Url], CPH.[DisplayOrder]
    FROM [Venue].[CourtPhotos] CPH
    INNER JOIN [Venue].[Courts] C ON C.[CourtID] = CPH.[CourtID]
    WHERE C.[VenueID] = @VenueID AND C.[StatusID] = 1 AND @IsPublic = 1
    ORDER BY CPH.[CourtID], CPH.[DisplayOrder];

    SELECT DISTINCT PM.[PaymentMethodID], PM.[Code], PM.[Name], RTRIM(PM.[Currency]) AS [Currency], PM.[DisplayOrder]
    FROM [Venue].[VenuePaymentAccounts] VPA
    INNER JOIN [Catalog].[PaymentMethods] PM ON PM.[PaymentMethodID] = VPA.[PaymentMethodID]
    WHERE VPA.[VenueID] = @VenueID AND VPA.[StatusID] = 1 AND PM.[StatusID] = 1 AND @IsPublic = 1
    ORDER BY PM.[DisplayOrder];
END;
GO
