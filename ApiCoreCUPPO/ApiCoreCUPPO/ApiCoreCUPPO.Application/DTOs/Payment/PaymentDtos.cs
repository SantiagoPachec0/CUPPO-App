using System.ComponentModel.DataAnnotations;

namespace ApiCoreCUPPO.Application.DTOs.Payment
{
    /// <summary>Pago que registra el jugador (se envía como multipart junto con la foto del comprobante).</summary>
    public class CreatePaymentDto
    {
        [Range(1, int.MaxValue, ErrorMessage = "El método de pago es obligatorio.")]
        public int PaymentMethodID { get; set; }

        /// <summary>Cuenta del complejo a la que se pagó (obligatoria salvo en efectivo).</summary>
        public int? VenuePaymentAccountID { get; set; }

        /// <summary>Monto en la moneda del método (bolívares para Pago Móvil y transferencia).</summary>
        [Range(0.01, 100000000, ErrorMessage = "El monto debe ser mayor que cero.")]
        public decimal AmountPaid { get; set; }

        [Required(ErrorMessage = "La fecha del pago es obligatoria.")]
        public DateTime PaymentDate { get; set; }

        [StringLength(50)]
        public string? Reference { get; set; }

        [StringLength(150)]
        public string? PayerName { get; set; }

        [StringLength(20)]
        public string? PayerDocument { get; set; }

        [StringLength(20)]
        public string? PayerPhone { get; set; }
    }

    public class ReviewPaymentDto
    {
        public bool Approve { get; set; }

        /// <summary>Obligatorio al rechazar.</summary>
        [StringLength(250)]
        public string? RejectionReason { get; set; }
    }

    public class PendingPaymentDto
    {
        public int PaymentID { get; set; }
        public int BookingID { get; set; }
        public DateTime StartDateTime { get; set; }
        public DateTime EndDateTime { get; set; }
        public decimal TotalUSD { get; set; }
        public int VenueID { get; set; }
        public string VenueName { get; set; } = string.Empty;
        public string CourtName { get; set; } = string.Empty;
        public string PlayerName { get; set; } = string.Empty;
        public string PlayerMail { get; set; } = string.Empty;
        public int PaymentMethodID { get; set; }
        public string PaymentMethodName { get; set; } = string.Empty;
        public decimal AmountPaid { get; set; }
        public string Currency { get; set; } = string.Empty;
        public decimal? ExchangeRate { get; set; }
        public decimal AmountUSD { get; set; }
        public string? Reference { get; set; }
        public DateTime PaymentDate { get; set; }
        public string? PayerName { get; set; }
        public string? PayerDocument { get; set; }
        public string? PayerPhone { get; set; }
        public bool HasReceipt { get; set; }

        /// <summary>true si el monto en USD es menor que el total de la reserva.</summary>
        public bool IsUnderpaid { get; set; }
        public DateTime CreationDate { get; set; }
    }
}
