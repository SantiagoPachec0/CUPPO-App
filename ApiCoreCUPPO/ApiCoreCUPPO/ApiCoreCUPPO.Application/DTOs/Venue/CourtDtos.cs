using System.ComponentModel.DataAnnotations;

namespace ApiCoreCUPPO.Application.DTOs.Venue
{
    public class CourtUpsertDto
    {
        [Range(1, int.MaxValue, ErrorMessage = "El deporte es obligatorio.")]
        public int SportID { get; set; }

        public int? SurfaceID { get; set; }

        [Required(ErrorMessage = "El nombre es obligatorio.")]
        [StringLength(80, MinimumLength = 2)]
        public string Name { get; set; } = string.Empty;

        [StringLength(500)]
        public string? Description { get; set; }

        public bool IsCovered { get; set; }
        public bool HasLighting { get; set; }

        [Range(1, 100)]
        public int? PlayersCapacity { get; set; }

        /// <summary>Duración del turno en minutos (30 a 240, en bloques de 30).</summary>
        [Range(30, 240)]
        public int SlotMinutes { get; set; } = 60;
    }

    public class OwnerCourtDto
    {
        public int CourtID { get; set; }
        public int VenueID { get; set; }
        public int SportID { get; set; }
        public string SportName { get; set; } = string.Empty;
        public int? SurfaceID { get; set; }
        public string? SurfaceName { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }
        public bool IsCovered { get; set; }
        public bool HasLighting { get; set; }
        public int? PlayersCapacity { get; set; }
        public int SlotMinutes { get; set; }
        public int StatusID { get; set; }

        public IEnumerable<ScheduleItemDto> Schedule { get; set; } = [];
        public IEnumerable<PriceItemDto> Prices { get; set; } = [];
        public IEnumerable<CourtPhotoDto> Photos { get; set; } = [];
    }

    /// <summary>Franja de horario. dayOfWeek: 1 lunes ... 7 domingo. closeTime "00:00" = medianoche.</summary>
    public class ScheduleItemDto
    {
        [Range(1, 7)]
        public int DayOfWeek { get; set; }

        [Required, RegularExpression(@"^([01]\d|2[0-3]):(00|30)$", ErrorMessage = "Hora inválida (HH:00 o HH:30).")]
        public string OpenTime { get; set; } = string.Empty;

        [Required, RegularExpression(@"^([01]\d|2[0-3]):(00|30)$", ErrorMessage = "Hora inválida (HH:00 o HH:30).")]
        public string CloseTime { get; set; } = string.Empty;
    }

    /// <summary>Tarifa por hora en USD. dayOfWeek null = todos los días.</summary>
    public class PriceItemDto
    {
        [Range(1, 7)]
        public int? DayOfWeek { get; set; }

        [Required, RegularExpression(@"^([01]\d|2[0-3]):(00|30)$", ErrorMessage = "Hora inválida (HH:00 o HH:30).")]
        public string StartTime { get; set; } = string.Empty;

        [Required, RegularExpression(@"^([01]\d|2[0-3]):(00|30)$", ErrorMessage = "Hora inválida (HH:00 o HH:30).")]
        public string EndTime { get; set; } = string.Empty;

        [Range(0, 10000)]
        public decimal PricePerHourUSD { get; set; }
    }

    public class CourtPhotoDto
    {
        public int CourtPhotoID { get; set; }
        public int CourtID { get; set; }
        public string Url { get; set; } = string.Empty;
        public int DisplayOrder { get; set; }
    }

    // ---------- Bloqueos

    public class CourtBlockCreateDto
    {
        /// <summary>Hora local de Venezuela.</summary>
        [Required]
        public DateTime StartDateTime { get; set; }

        [Required]
        public DateTime EndDateTime { get; set; }

        [StringLength(250)]
        public string? Reason { get; set; }
    }

    public class CourtBlockDto
    {
        public int CourtBlockID { get; set; }
        public int CourtID { get; set; }
        public string CourtName { get; set; } = string.Empty;
        public DateTime StartDateTime { get; set; }
        public DateTime EndDateTime { get; set; }
        public string? Reason { get; set; }
    }
}
