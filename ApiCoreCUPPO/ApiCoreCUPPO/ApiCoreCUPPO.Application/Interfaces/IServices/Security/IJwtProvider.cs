using ApiCoreCUPPO.Domain.Entities;

namespace ApiCoreCUPPO.Application.Interfaces.IServices.Security
{
    public interface IJwtProvider
    {
        /// <summary>Genera el token de acceso (JWT) con los roles del usuario.</summary>
        (string Token, DateTime ExpiresAt) GenerateToken(User user, IEnumerable<string> roles);

        /// <summary>Genera un refresh token aleatorio. Solo su hash se guarda en la base.</summary>
        (string Token, byte[] Hash, DateTime ExpiresAt) GenerateRefreshToken();

        /// <summary>Hash SHA-256 de un token o código, para guardarlo y compararlo en la base.</summary>
        byte[] HashToken(string token);
    }
}
