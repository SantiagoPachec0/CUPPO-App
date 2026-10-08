using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;

namespace ApiCoreCUPPO.API.Extensions
{
    public static class ClaimsPrincipalExtensions
    {
        /// <summary>
        /// Obtiene el UserID del usuario autenticado a partir del claim "sub" del JWT.
        /// </summary>
        public static int GetUserId(this ClaimsPrincipal user)
        {
            var sub = user.FindFirstValue(JwtRegisteredClaimNames.Sub);

            return int.TryParse(sub, out var userId)
                ? userId
                : throw new UnauthorizedAccessException("El token no contiene un identificador de usuario válido.");
        }
    }
}
