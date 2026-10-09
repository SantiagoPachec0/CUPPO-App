namespace ApiCoreCUPPO.Application.DTOs.Security
{
    /// <summary>Datos mínimos para validar un inicio de sesión (resultado de Security.GetUserForLogin).</summary>
    public class UserLoginDataDto
    {
        public int UserID { get; set; }
        public string? PasswordBcrypt { get; set; }
        public bool HasLegacyPassword { get; set; }
        public bool Blocked { get; set; }
        public int StatusID { get; set; }
    }
}
