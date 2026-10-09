using System.ComponentModel.DataAnnotations;

namespace ApiCoreCUPPO.Application.DTOs.Booking
{
    /// <summary>Turno de una cancha para una fecha. Horas locales de Venezuela.</summary>
    public class AvailabilitySlotDto
    {
        public DateTime SlotStart { get; set; }
        public DateTime SlotEnd { get; set; }
        public decimal? PriceUSD { get; set; }
        public bool IsAvailable { get; set; }
    }

    public class CreateBookingDto
    {
        [Range(1, int.MaxValue, ErrorMessage = "La cancha es obligatoria.")]
        public int CourtID { get; set; }

        /// <summary>Hora local de Venezuela, en punto o y media. Ej: 2026-10-12T19:00:00.</summary>
        [Required(ErrorMessage = "La hora de inicio es obligatoria.")]
        public DateTime StartDateTime { get; set; }

        /// <summary>Minutos (múltiplo de 30, mínimo el turno de la cancha).</summary>
        [Range(30, 240, ErrorMessage = "La duración debe ser de 30 a 240 minutos.")]
        public int DurationMinutes { get; set; }

        [StringLength(500)]
        public string? Notes { get; set; }
    }

    public class CancelBookingDto
    {
        [StringLength(250)]
        public string? Reason { get; set; }
    }

    public class BookingListItemDto
    {
        public int BookingID { get; set; }
        public DateTime StartDateTime { get; set; }
        public DateTime EndDateTime { get; set; }
        public decimal TotalUSD { get; set; }
        public int BookingStatusID { get; set; }
        public string BookingStatusCode { get; set; } = string.Empty;
        public string BookingStatusName { get; set; } = string.Empty;

        /// <summary>UTC. Límite para registrar el pago (solo PENDING_PAYMENT).</summary>
        public DateTime? ExpiresAt { get; set; }
        public int CourtID { get; set; }
        public string CourtName { get; set; } = string.Empty;
        public string SportName { get; set; } = string.Empty;
        public int VenueID { get; set; }
        public string VenueName { get; set; } = string.Empty;
        public string VenueAddress { get; set; } = string.Empty;
        public string? CoverUrl { get; set; }

        [System.Text.Json.Serialization.JsonIgnore]
        public int TotalCount { get; set; }
    }

    public class BookingDetailDto
    {
        public int BookingID { get; set; }
        public DateTime StartDateTime { get; set; }
        public DateTime EndDateTime { get; set; }
        public decimal PriceUSD { get; set; }
        public decimal FeeUSD { get; set; }
        public decimal TotalUSD { get; set; }

        /// <summary>Tasa BCV vigente y el total equivalente en bolívares (referencial).</summary>
        public decimal? ExchangeRate { get; set; }
        public decimal? TotalVES { get; set; }

        public int BookingStatusID { get; set; }
        public string BookingStatusCode { get; set; } = string.Empty;
        public string BookingStatusName { get; set; } = string.Empty;
        public DateTime? ExpiresAt { get; set; }
        public string? Notes { get; set; }
        public string? CancelReason { get; set; }
        public DateTime CreationDate { get; set; }

        public int CourtID { get; set; }
        public string CourtName { get; set; } = string.Empty;
        public string SportName { get; set; } = string.Empty;
        public int VenueID { get; set; }
        public string VenueName { get; set; } = string.Empty;
        public string VenueAddress { get; set; } = string.Empty;
        public string? VenuePhone { get; set; }
        public string? VenueWhatsApp { get; set; }
        public decimal? Latitude { get; set; }
        public decimal? Longitude { get; set; }
        public int CancellationHours { get; set; }

        public int PlayerUserID { get; set; }
        public string PlayerName { get; set; } = string.Empty;
        public string PlayerMail { get; set; } = string.Empty;

        /// <summary>true si quien consulta es el dueño del complejo.</summary>
        public bool IsOwnerView { get; set; }

        /// <summary>Cuentas del complejo a las que se puede pagar.</summary>
        public IEnumerable<PaymentInstructionDto> PaymentAccounts { get; set; } = [];
        public IEnumerable<PaymentSummaryDto> Payments { get; set; } = [];
    }

    public class PaymentInstructionDto
    {
        public int VenuePaymentAccountID { get; set; }
        public int PaymentMethodID { get; set; }
        public string PaymentMethodCode { get; set; } = string.Empty;
        public string PaymentMethodName { get; set; } = string.Empty;
        public string Currency { get; set; } = string.Empty;
        public bool RequiresReference { get; set; }
        public bool IsOnline { get; set; }
        public string? BankName { get; set; }
        public string? AccountHolder { get; set; }
        public string? DocumentNumber { get; set; }
        public string? Phone { get; set; }
        public string? AccountNumber { get; set; }
        public string? Email { get; set; }
        public string? Notes { get; set; }
    }

    public class PaymentSummaryDto
    {
        public int PaymentID { get; set; }
        public int PaymentMethodID { get; set; }
        public string PaymentMethodName { get; set; } = string.Empty;
        public decimal AmountPaid { get; set; }
        public string Currency { get; set; } = string.Empty;
        public decimal? ExchangeRate { get; set; }
        public decimal AmountUSD { get; set; }
        public string? Reference { get; set; }
        public DateTime PaymentDate { get; set; }
        public string? PayerName { get; set; }
        public bool HasReceipt { get; set; }
        public int PaymentStatusID { get; set; }
        public string PaymentStatusCode { get; set; } = string.Empty;
        public string PaymentStatusName { get; set; } = string.Empty;
        public string? RejectionReason { get; set; }
        public DateTime CreationDate { get; set; }
        public DateTime? ReviewedDate { get; set; }
    }

    // ---------- Panel de dueño

    public class AgendaItemDto
    {
        public int BookingID { get; set; }
        public DateTime StartDateTime { get; set; }
        public DateTime EndDateTime { get; set; }
        public decimal TotalUSD { get; set; }
        public int BookingStatusID { get; set; }
        public string BookingStatusCode { get; set; } = string.Empty;
        public string BookingStatusName { get; set; } = string.Empty;
        public DateTime? ExpiresAt { get; set; }
        public int CourtID { get; set; }
        public string CourtName { get; set; } = string.Empty;
        public int PlayerUserID { get; set; }
        public string PlayerName { get; set; } = string.Empty;
        public string PlayerMail { get; set; } = string.Empty;
        public string? Notes { get; set; }
        public int? LastPaymentID { get; set; }
        public string? LastPaymentStatusCode { get; set; }
    }
}
