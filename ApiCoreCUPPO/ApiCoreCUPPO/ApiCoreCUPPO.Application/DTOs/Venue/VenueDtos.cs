using ApiCoreCUPPO.Application.DTOs.Catalog;
using System.ComponentModel.DataAnnotations;

namespace ApiCoreCUPPO.Application.DTOs.Venue
{
    /// <summary>Datos para crear o editar un complejo.</summary>
    public class VenueUpsertDto
    {
        [Required(ErrorMessage = "El nombre es obligatorio.")]
        [StringLength(100, MinimumLength = 3)]
        public string Name { get; set; } = string.Empty;

        [StringLength(1000)]
        public string? Description { get; set; }

        [Range(1, int.MaxValue, ErrorMessage = "La zona es obligatoria.")]
        public int ZoneID { get; set; }

        [Required(ErrorMessage = "La dirección es obligatoria.")]
        [StringLength(250, MinimumLength = 5)]
        public string Address { get; set; } = string.Empty;

        [Range(-90, 90)]
        public decimal? Latitude { get; set; }

        [Range(-180, 180)]
        public decimal? Longitude { get; set; }

        [RegularExpression(@"^0\d{10}$", ErrorMessage = "Teléfono inválido. Ejemplo: 02121234567.")]
        public string? Phone { get; set; }

        [RegularExpression(@"^0\d{10}$", ErrorMessage = "WhatsApp inválido. Ejemplo: 04121234567.")]
        public string? WhatsApp { get; set; }

        [StringLength(50)]
        public string? Instagram { get; set; }

        /// <summary>Minutos que tiene el jugador para registrar el pago.</summary>
        [Range(5, 1440)]
        public int BookingHoldMinutes { get; set; } = 30;

        /// <summary>Horas de anticipación con las que el jugador puede cancelar una reserva confirmada.</summary>
        [Range(0, 168)]
        public int CancellationHours { get; set; } = 24;
    }

    public class OwnerVenueSummaryDto
    {
        public int VenueID { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Address { get; set; } = string.Empty;
        public string ZoneName { get; set; } = string.Empty;
        public string CityName { get; set; } = string.Empty;
        public int VerificationStatusID { get; set; }
        public string VerificationStatusCode { get; set; } = string.Empty;
        public string VerificationStatusName { get; set; } = string.Empty;
        public string? VerificationNotes { get; set; }
        public int StatusID { get; set; }
        public int CourtCount { get; set; }
        public string? CoverUrl { get; set; }
    }

    public class OwnerVenueDto
    {
        public int VenueID { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }
        public int ZoneID { get; set; }
        public string ZoneName { get; set; } = string.Empty;
        public int CityID { get; set; }
        public string CityName { get; set; } = string.Empty;
        public string Address { get; set; } = string.Empty;
        public decimal? Latitude { get; set; }
        public decimal? Longitude { get; set; }
        public string? Phone { get; set; }
        public string? WhatsApp { get; set; }
        public string? Instagram { get; set; }
        public int BookingHoldMinutes { get; set; }
        public int CancellationHours { get; set; }
        public int VerificationStatusID { get; set; }
        public string VerificationStatusCode { get; set; } = string.Empty;
        public string VerificationStatusName { get; set; } = string.Empty;
        public string? VerificationNotes { get; set; }
        public int StatusID { get; set; }

        public IEnumerable<VenuePhotoDto> Photos { get; set; } = [];
        public IEnumerable<AmenityDto> Amenities { get; set; } = [];
        public IEnumerable<PaymentAccountDto> PaymentAccounts { get; set; } = [];
    }

    public class VenuePhotoDto
    {
        public int VenuePhotoID { get; set; }
        public string Url { get; set; } = string.Empty;
        public bool IsCover { get; set; }
        public int DisplayOrder { get; set; }
    }

    public class StatusDto
    {
        [Range(1, 3, ErrorMessage = "Estado inválido.")]
        public int StatusID { get; set; }
    }

    public class AmenityIdsDto
    {
        public List<int> AmenityIDs { get; set; } = [];
    }

    // ---------- Cuentas de cobro

    public class PaymentAccountDto
    {
        public int VenuePaymentAccountID { get; set; }
        public int PaymentMethodID { get; set; }
        public string PaymentMethodCode { get; set; } = string.Empty;
        public string PaymentMethodName { get; set; } = string.Empty;
        public string Currency { get; set; } = string.Empty;
        public string? BankName { get; set; }
        public string? AccountHolder { get; set; }
        public string? DocumentNumber { get; set; }
        public string? Phone { get; set; }
        public string? AccountNumber { get; set; }
        public string? Email { get; set; }
        public string? Notes { get; set; }
        public int StatusID { get; set; }
    }

    /// <summary>
    /// Datos según el método: Pago Móvil (banco, cédula/RIF, teléfono), transferencia (banco, titular,
    /// cédula/RIF, cuenta), Zelle (titular, correo), Binance (correo), efectivo (ninguno).
    /// </summary>
    public class PaymentAccountUpsertDto
    {
        [Range(1, int.MaxValue, ErrorMessage = "El método de pago es obligatorio.")]
        public int PaymentMethodID { get; set; }

        [StringLength(80)] public string? BankName { get; set; }
        [StringLength(150)] public string? AccountHolder { get; set; }
        [StringLength(20)] public string? DocumentNumber { get; set; }
        [StringLength(20)] public string? Phone { get; set; }
        [StringLength(30)] public string? AccountNumber { get; set; }
        [StringLength(100)] [EmailAddress] public string? Email { get; set; }
        [StringLength(250)] public string? Notes { get; set; }
    }

    // ---------- Revisión de complejos (SUPERADMIN)

    public class VenueRequestDto
    {
        public int VenueID { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Address { get; set; } = string.Empty;
        public string ZoneName { get; set; } = string.Empty;
        public string CityName { get; set; } = string.Empty;
        public int OwnerUserID { get; set; }
        public string OwnerName { get; set; } = string.Empty;
        public string OwnerMail { get; set; } = string.Empty;
        public string OwnerLegalName { get; set; } = string.Empty;
        public int VerificationStatusID { get; set; }
        public string VerificationStatusCode { get; set; } = string.Empty;
        public string VerificationStatusName { get; set; } = string.Empty;
        public string? VerificationNotes { get; set; }
        public int StatusID { get; set; }
        public DateTime CreationDate { get; set; }
        public int CourtCount { get; set; }
        public int PhotoCount { get; set; }
    }
}
