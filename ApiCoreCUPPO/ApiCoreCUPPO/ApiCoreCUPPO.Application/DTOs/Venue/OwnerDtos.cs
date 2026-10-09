using System.ComponentModel.DataAnnotations;

namespace ApiCoreCUPPO.Application.DTOs.Venue
{
    /// <summary>Solicitud para ser dueño de complejo (queda pendiente hasta que CUPPO la revise).</summary>
    public class OwnerVerificationRequestDto
    {
        /// <summary>V = venezolano, E = extranjero, J = jurídico (RIF), G = gobierno, P = pasaporte.</summary>
        [Required(ErrorMessage = "El tipo de documento es obligatorio.")]
        [RegularExpression("^[VEJGP]$", ErrorMessage = "Tipo de documento inválido. Use V, E, J, G o P.")]
        public string DocumentType { get; set; } = string.Empty;

        [Required(ErrorMessage = "El número de documento es obligatorio.")]
        [RegularExpression(@"^\d{5,10}$", ErrorMessage = "El número de documento debe tener entre 5 y 10 dígitos, sin puntos ni guiones.")]
        public string DocumentNumber { get; set; } = string.Empty;

        [Required(ErrorMessage = "El nombre o razón social es obligatorio.")]
        [StringLength(150, MinimumLength = 3)]
        public string LegalName { get; set; } = string.Empty;

        [Required(ErrorMessage = "El teléfono es obligatorio.")]
        [RegularExpression(@"^0\d{10}$", ErrorMessage = "Teléfono inválido. Ejemplo: 04121234567.")]
        public string Phone { get; set; } = string.Empty;
    }

    public class OwnerProfileDto
    {
        public int UserID { get; set; }
        public string DocumentType { get; set; } = string.Empty;
        public string DocumentNumber { get; set; } = string.Empty;
        public string LegalName { get; set; } = string.Empty;
        public string Phone { get; set; } = string.Empty;
        public string? DocumentUrl { get; set; }
        public int VerificationStatusID { get; set; }
        public string VerificationStatusCode { get; set; } = string.Empty;
        public string VerificationStatusName { get; set; } = string.Empty;
        public string? ReviewNotes { get; set; }
        public DateTime? ReviewedDate { get; set; }
        public DateTime CreationDate { get; set; }
    }

    /// <summary>Solicitud de dueño vista por el administrador.</summary>
    public class OwnerRequestDto : OwnerProfileDto
    {
        public string UserLogin { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string Mail { get; set; } = string.Empty;
        public int VenueCount { get; set; }
    }

    public class ReviewOwnerDto
    {
        /// <summary>2 = aprobar, 3 = rechazar, 4 = suspender.</summary>
        [Range(2, 4, ErrorMessage = "Estado inválido: 2 aprobar, 3 rechazar, 4 suspender.")]
        public int VerificationStatusID { get; set; }

        [StringLength(500)]
        public string? ReviewNotes { get; set; }
    }
}
