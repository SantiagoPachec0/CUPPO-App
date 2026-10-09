using ApiCoreCUPPO.Application.DTOs.Venue;

namespace ApiCoreCUPPO.Application.DTOs.Security
{
    public class UserProfileDto
    {
        public int UserID { get; set; }
        public string UserLogin { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string Mail { get; set; } = string.Empty;
        public IEnumerable<string> Roles { get; set; } = [];

        /// <summary>
        /// Solicitud de dueño, si existe. Si se aprobó después del último login, la app debe
        /// llamar a api/auth/refresh para recibir el rol en el token.
        /// </summary>
        public OwnerProfileDto? OwnerProfile { get; set; }
    }
}
