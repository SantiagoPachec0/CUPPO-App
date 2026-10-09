using ApiCoreCUPPO.Application.DTOs.Catalog;
using System.ComponentModel.DataAnnotations;

namespace ApiCoreCUPPO.Application.DTOs.Venue
{
    /// <summary>Filtros de búsqueda (todos opcionales).</summary>
    public class VenueSearchQueryDto
    {
        public int? SportID { get; set; }
        public int? CityID { get; set; }
        public int? ZoneID { get; set; }

        /// <summary>Texto libre: nombre del complejo o de la zona.</summary>
        [StringLength(100)]
        public string? Search { get; set; }

        /// <summary>Ubicación del jugador: si se envía, ordena por distancia.</summary>
        [Range(-90, 90)]
        public decimal? Latitude { get; set; }

        [Range(-180, 180)]
        public decimal? Longitude { get; set; }

        [Range(1, 1000)]
        public int Page { get; set; } = 1;

        [Range(1, 50)]
        public int PageSize { get; set; } = 20;
    }

    public class VenueSearchItemDto
    {
        public int VenueID { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Address { get; set; } = string.Empty;
        public int ZoneID { get; set; }
        public string ZoneName { get; set; } = string.Empty;
        public int CityID { get; set; }
        public string CityName { get; set; } = string.Empty;
        public decimal? Latitude { get; set; }
        public decimal? Longitude { get; set; }
        public decimal? DistanceKm { get; set; }
        public decimal? AvgRating { get; set; }
        public int ReviewCount { get; set; }
        public string? CoverUrl { get; set; }
        public decimal? MinPricePerHourUSD { get; set; }

        /// <summary>Deportes disponibles, separados por coma.</summary>
        public string? Sports { get; set; }

        [System.Text.Json.Serialization.JsonIgnore]
        public int TotalCount { get; set; }
    }

    public class PublicVenueDto
    {
        public int VenueID { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }
        public string Address { get; set; } = string.Empty;
        public decimal? Latitude { get; set; }
        public decimal? Longitude { get; set; }
        public int ZoneID { get; set; }
        public string ZoneName { get; set; } = string.Empty;
        public int CityID { get; set; }
        public string CityName { get; set; } = string.Empty;
        public string? Phone { get; set; }
        public string? WhatsApp { get; set; }
        public string? Instagram { get; set; }

        /// <summary>Horas de anticipación para cancelar una reserva confirmada.</summary>
        public int CancellationHours { get; set; }
        public decimal? AvgRating { get; set; }
        public int ReviewCount { get; set; }

        public IEnumerable<VenuePhotoDto> Photos { get; set; } = [];
        public IEnumerable<AmenityDto> Amenities { get; set; } = [];
        public IEnumerable<PublicCourtDto> Courts { get; set; } = [];
        public IEnumerable<AcceptedPaymentMethodDto> PaymentMethods { get; set; } = [];
    }

    public class PublicCourtDto
    {
        public int CourtID { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }
        public int SportID { get; set; }
        public string SportCode { get; set; } = string.Empty;
        public string SportName { get; set; } = string.Empty;
        public int? SurfaceID { get; set; }
        public string? SurfaceName { get; set; }
        public bool IsCovered { get; set; }
        public bool HasLighting { get; set; }
        public int? PlayersCapacity { get; set; }
        public int SlotMinutes { get; set; }
        public decimal? MinPricePerHourUSD { get; set; }
        public decimal? MaxPricePerHourUSD { get; set; }
        public IEnumerable<CourtPhotoDto> Photos { get; set; } = [];
    }

    public class AcceptedPaymentMethodDto
    {
        public int PaymentMethodID { get; set; }
        public string Code { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string Currency { get; set; } = string.Empty;
    }
}
