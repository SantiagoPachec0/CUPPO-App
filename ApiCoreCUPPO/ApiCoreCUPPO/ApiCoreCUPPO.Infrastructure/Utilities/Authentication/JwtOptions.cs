namespace ApiCoreCUPPO.Infrastructure.Utilities.Authentication
{
    public class JwtOptions
    {
        public string SecretKey { get; set; } = string.Empty;
        public string Issuer { get; set; } = string.Empty;
        public string Audience { get; set; } = string.Empty;

        /// <summary>Vida del token de acceso. Corta, porque los roles viajan en él.</summary>
        public int ExpirationMinutes { get; set; } = 60;

        /// <summary>Vida del refresh token (sesión en el dispositivo).</summary>
        public int RefreshTokenDays { get; set; } = 30;
    }
}
