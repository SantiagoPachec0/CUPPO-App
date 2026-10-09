using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Security;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Security;
using ApiCoreCUPPO.Application.Interfaces.IServices.Common;
using ApiCoreCUPPO.Application.Interfaces.IServices.Security;
using System.Security.Cryptography;

namespace ApiCoreCUPPO.Application.Services.Security
{
    public class AuthService : IAuthService
    {
        private const string InvalidCredentials = "Credenciales inválidas.";
        private const string ForgotPasswordMessage = "Si el correo está registrado, te enviamos un código para restablecer tu contraseña.";
        private static readonly TimeSpan ResetCodeLifetime = TimeSpan.FromMinutes(15);

        // Hash válido de una contraseña aleatoria: se verifica cuando el usuario no existe
        // para que la respuesta tarde lo mismo y no revele qué usuarios existen.
        private static string? _dummyHash;

        private readonly ISecurityRepository _securityRepository;
        private readonly IJwtProvider _jwtProvider;
        private readonly IPasswordHasher _passwordHasher;
        private readonly IEmailSender _emailSender;

        public AuthService(ISecurityRepository securityRepository, IJwtProvider jwtProvider, IPasswordHasher passwordHasher, IEmailSender emailSender)
        {
            _securityRepository = securityRepository;
            _jwtProvider = jwtProvider;
            _passwordHasher = passwordHasher;
            _emailSender = emailSender;
        }

        public async Task<(bool IsSuccess, AuthResponseDto? Data, string Message)> RegisterAsync(RegisterUserDto dto, string? deviceInfo)
        {
            var spResult = await _securityRepository.InsertUserAsync(dto, _passwordHasher.Hash(dto.Password));
            if (!spResult.IsSuccess)
                return (false, null, spResult.MessageResult);

            return await IssueSessionAsync(spResult.CodeResult, deviceInfo, spResult.MessageResult);
        }

        public async Task<(bool IsSuccess, AuthResponseDto? Data, string Message)> LoginAsync(LoginRequestDto dto, string? deviceInfo)
        {
            var user = await _securityRepository.GetUserForLoginAsync(dto.Identifier);
            if (user is null)
            {
                _dummyHash ??= _passwordHasher.Hash(Guid.NewGuid().ToString());
                _passwordHasher.Verify(dto.Password, _dummyHash);
                return (false, null, InvalidCredentials);
            }

            if (user.Blocked || user.StatusID != 1)
                return (false, null, "La cuenta de usuario se encuentra bloqueada o inactiva.");

            if (user.PasswordBcrypt is not null)
            {
                var isValid = _passwordHasher.Verify(dto.Password, user.PasswordBcrypt);
                var attempt = await _securityRepository.RegisterLoginAttemptAsync(user.UserID, isValid);
                if (!isValid)
                    return (false, null, attempt.MessageResult);
            }
            else if (user.HasLegacyPassword)
            {
                // Usuario con el hash anterior: se valida en SQL y, si es correcto, se migra a BCrypt
                var legacy = await _securityRepository.ValidateLegacyLoginAsync(dto.Identifier, dto.Password);
                if (!legacy.IsSuccess)
                    return (false, null, legacy.MessageResult);

                await _securityRepository.SetUserPasswordAsync(user.UserID, _passwordHasher.Hash(dto.Password), revokeSessions: false, unblock: false);
            }
            else
            {
                return (false, null, InvalidCredentials);
            }

            return await IssueSessionAsync(user.UserID, deviceInfo, "Autenticación exitosa.");
        }

        public async Task<(bool IsSuccess, AuthResponseDto? Data, string Message)> RefreshAsync(string refreshToken, string? deviceInfo)
        {
            var (newToken, newHash, newExpiresAt) = _jwtProvider.GenerateRefreshToken();
            var spResult = await _securityRepository.RotateRefreshTokenAsync(_jwtProvider.HashToken(refreshToken), newHash, newExpiresAt, deviceInfo);
            if (!spResult.IsSuccess)
                return (false, null, spResult.MessageResult);

            return await BuildResponseAsync(spResult.CodeResult, newToken, newExpiresAt, spResult.MessageResult);
        }

        public async Task LogoutAsync(string refreshToken)
        {
            await _securityRepository.RevokeRefreshTokenAsync(_jwtProvider.HashToken(refreshToken));
        }

        public async Task<(bool IsSuccess, AuthResponseDto? Data, string Message)> ChangePasswordAsync(int userId, ChangePasswordDto dto, string? deviceInfo)
        {
            var user = await _securityRepository.GetUserByIdAsync(userId);
            if (user is null)
                return (false, null, "El usuario no existe.");

            bool isValid;
            if (user.PasswordBcrypt is not null)
                isValid = _passwordHasher.Verify(dto.CurrentPassword, user.PasswordBcrypt);
            else
                isValid = (await _securityRepository.ValidateLegacyLoginAsync(user.UserLogin, dto.CurrentPassword)).IsSuccess;

            if (!isValid)
                return (false, null, "La contraseña actual no es correcta.");

            // Cierra todas las sesiones y abre una nueva en este dispositivo
            var spResult = await _securityRepository.SetUserPasswordAsync(userId, _passwordHasher.Hash(dto.NewPassword), revokeSessions: true, unblock: false);
            if (!spResult.IsSuccess)
                return (false, null, spResult.MessageResult);

            return await IssueSessionAsync(userId, deviceInfo, "Contraseña actualizada. Se cerró la sesión en tus otros dispositivos.");
        }

        public async Task<string> ForgotPasswordAsync(ForgotPasswordDto dto)
        {
            var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
            var spResult = await _securityRepository.CreatePasswordResetCodeAsync(dto.Mail, HashResetCode(dto.Mail, code), DateTime.UtcNow.Add(ResetCodeLifetime));

            if (spResult.IsSuccess)
            {
                await _emailSender.SendAsync(
                    dto.Mail,
                    "CUPPO - Código para restablecer tu contraseña",
                    $"Tu código es {code}. Vence en {ResetCodeLifetime.TotalMinutes:0} minutos.\n\nSi no lo pediste, ignora este correo.");
            }

            return ForgotPasswordMessage;
        }

        public async Task<SpResultDto> ResetPasswordAsync(ResetPasswordDto dto)
        {
            var consumed = await _securityRepository.ConsumePasswordResetCodeAsync(dto.Mail, HashResetCode(dto.Mail, dto.Code));
            if (!consumed.IsSuccess)
                return consumed;

            // Comprobó que es dueño del correo: se desbloquea la cuenta y se cierran las sesiones
            var spResult = await _securityRepository.SetUserPasswordAsync(consumed.CodeResult, _passwordHasher.Hash(dto.NewPassword), revokeSessions: true, unblock: true);
            if (spResult.IsSuccess)
                spResult.MessageResult = "Contraseña restablecida. Ya puedes iniciar sesión.";

            return spResult;
        }

        // ---------- Helpers

        private byte[] HashResetCode(string mail, string code)
            => _jwtProvider.HashToken($"{mail.Trim().ToLowerInvariant()}:{code}");

        /// <summary>Crea un refresh token nuevo para el usuario y arma la respuesta de sesión.</summary>
        private async Task<(bool IsSuccess, AuthResponseDto? Data, string Message)> IssueSessionAsync(int userId, string? deviceInfo, string message)
        {
            var (refreshToken, refreshHash, refreshExpiresAt) = _jwtProvider.GenerateRefreshToken();
            var inserted = await _securityRepository.InsertRefreshTokenAsync(userId, refreshHash, refreshExpiresAt, deviceInfo);
            if (!inserted.IsSuccess)
                return (false, null, inserted.MessageResult);

            return await BuildResponseAsync(userId, refreshToken, refreshExpiresAt, message);
        }

        private async Task<(bool IsSuccess, AuthResponseDto? Data, string Message)> BuildResponseAsync(int userId, string refreshToken, DateTime refreshExpiresAt, string message)
        {
            var user = await _securityRepository.GetUserByIdAsync(userId);
            if (user is null)
                return (false, null, "El usuario no existe o se encuentra inactivo.");

            var roles = (await _securityRepository.GetUserRolesAsync(userId)).ToList();
            var permissions = await _securityRepository.GetUserPermissionsAsync(userId);
            var (token, tokenExpiresAt) = _jwtProvider.GenerateToken(user, roles);

            return (true, new AuthResponseDto
            {
                UserID = user.UserID,
                UserLogin = user.UserLogin,
                Name = user.Name,
                Mail = user.Mail,
                Token = token,
                TokenExpiresAt = tokenExpiresAt,
                RefreshToken = refreshToken,
                RefreshTokenExpiresAt = refreshExpiresAt,
                Roles = roles,
                Permissions = permissions
            }, message);
        }
    }
}
