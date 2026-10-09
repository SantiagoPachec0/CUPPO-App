using System.ComponentModel.DataAnnotations;

namespace ApiCoreCUPPO.Application.DTOs.Security
{
    public class ForgotPasswordDto
    {
        [Required(ErrorMessage = "El correo es obligatorio.")]
        [EmailAddress(ErrorMessage = "Formato de correo no válido.")]
        public string Mail { get; set; } = string.Empty;
    }
}
