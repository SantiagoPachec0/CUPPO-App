namespace ApiCoreCUPPO.Application.DTOs.Security
{
    public class AuthResponseDto
    {
        public int UserID { get; set; }
        public string UserLogin { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string Mail { get; set; } = string.Empty;

        /// <summary>Token de acceso (JWT). Se envía en el header Authorization: Bearer.</summary>
        public string Token { get; set; } = string.Empty;
        public DateTime TokenExpiresAt { get; set; }

        /// <summary>Token para renovar la sesión (POST api/auth/refresh). Guardar en almacenamiento seguro.</summary>
        public string RefreshToken { get; set; } = string.Empty;
        public DateTime RefreshTokenExpiresAt { get; set; }

        public IEnumerable<string> Roles { get; set; } = new List<string>();
        public IEnumerable<UserPermissionDto> Permissions { get; set; } = new List<UserPermissionDto>();
    }
}
