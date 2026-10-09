using System.ComponentModel.DataAnnotations;

namespace ApiCoreCUPPO.Application.DTOs.Security
{
    public class RefreshTokenRequestDto
    {
        [Required(ErrorMessage = "El refresh token es obligatorio.")]
        public string RefreshToken { get; set; } = string.Empty;
    }
}
