using System.ComponentModel.DataAnnotations;

namespace ApiCoreCUPPO.Application.DTOs.Security
{
    public class ChangePasswordDto
    {
        [Required(ErrorMessage = "La contraseña actual es obligatoria.")]
        public string CurrentPassword { get; set; } = string.Empty;

        [Required(ErrorMessage = "La nueva contraseña es obligatoria.")]
        [MinLength(8, ErrorMessage = "La contraseña debe tener mínimo 8 caracteres.")]
        [MaxLength(72, ErrorMessage = "La contraseña debe tener máximo 72 caracteres.")]
        public string NewPassword { get; set; } = string.Empty;
    }
}
