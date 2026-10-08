using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Text;

namespace ApiCoreCUPPO.Application.DTOs.Security
{
    public class LoginRequestDto
    {
        [Required(ErrorMessage = "El identificador de usuario o correo es obligatorio.")]
        public string Identifier { get; set; } = string.Empty;

        [Required(ErrorMessage = "La contraseña es obligatoria.")]
        public string Password { get; set; } = string.Empty;
    }
}
