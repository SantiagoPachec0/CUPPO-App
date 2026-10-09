using System.ComponentModel.DataAnnotations;

namespace ApiCoreCUPPO.Application.DTOs.Security
{
    public class ResetPasswordDto
    {
        [Required(ErrorMessage = "El correo es obligatorio.")]
        [EmailAddress(ErrorMessage = "Formato de correo no válido.")]
        public string Mail { get; set; } = string.Empty;

        [Required(ErrorMessage = "El código es obligatorio.")]
        [RegularExpression(@"^\d{6}$", ErrorMessage = "El código debe tener 6 dígitos.")]
        public string Code { get; set; } = string.Empty;

        [Required(ErrorMessage = "La nueva contraseña es obligatoria.")]
        [MinLength(8, ErrorMessage = "La contraseña debe tener mínimo 8 caracteres.")]
        [MaxLength(72, ErrorMessage = "La contraseña debe tener máximo 72 caracteres.")]
        public string NewPassword { get; set; } = string.Empty;
    }
}
