namespace ApiCoreCUPPO.API.Extensions
{
    public static class HttpContextExtensions
    {
        /// <summary>Descripción corta del dispositivo (User-Agent) para identificar la sesión.</summary>
        public static string? GetDeviceInfo(this HttpContext context)
        {
            var userAgent = context.Request.Headers.UserAgent.ToString();
            if (string.IsNullOrWhiteSpace(userAgent))
                return null;

            return userAgent.Length <= 200 ? userAgent : userAgent[..200];
        }
    }
}
