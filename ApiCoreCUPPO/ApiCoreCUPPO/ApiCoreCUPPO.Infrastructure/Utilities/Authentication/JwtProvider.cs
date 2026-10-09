using ApiCoreCUPPO.Application.Interfaces.IServices.Security;
using ApiCoreCUPPO.Domain.Entities;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;

namespace ApiCoreCUPPO.Infrastructure.Utilities.Authentication
{
    public class JwtProvider : IJwtProvider
    {
        /// <summary>Nombre del claim de rol. Program.cs lo usa como RoleClaimType.</summary>
        public const string RoleClaim = "role";

        private readonly JwtOptions _options;

        public JwtProvider(IOptions<JwtOptions> options)
        {
            _options = options.Value;
        }

        public (string Token, DateTime ExpiresAt) GenerateToken(User user, IEnumerable<string> roles)
        {
            var claims = new List<Claim>
            {
                new(JwtRegisteredClaimNames.Sub, user.UserID.ToString()),
                new(JwtRegisteredClaimNames.Name, user.Name),
                new(JwtRegisteredClaimNames.Email, user.Mail),
                new("UserLogin", user.UserLogin),
                new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
            };
            claims.AddRange(roles.Select(role => new Claim(RoleClaim, role)));

            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_options.SecretKey));
            var expiresAt = DateTime.UtcNow.AddMinutes(_options.ExpirationMinutes);

            var tokenDescriptor = new SecurityTokenDescriptor
            {
                Subject = new ClaimsIdentity(claims),
                Expires = expiresAt,
                Issuer = _options.Issuer,
                Audience = _options.Audience,
                SigningCredentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256)
            };

            var tokenHandler = new JwtSecurityTokenHandler();
            var token = tokenHandler.CreateToken(tokenDescriptor);

            return (tokenHandler.WriteToken(token), expiresAt);
        }

        public (string Token, byte[] Hash, DateTime ExpiresAt) GenerateRefreshToken()
        {
            var token = Base64UrlEncoder.Encode(RandomNumberGenerator.GetBytes(64));
            return (token, HashToken(token), DateTime.UtcNow.AddDays(_options.RefreshTokenDays));
        }

        public byte[] HashToken(string token) => SHA256.HashData(Encoding.UTF8.GetBytes(token));
    }
}
