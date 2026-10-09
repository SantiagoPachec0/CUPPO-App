using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Security;
using ApiCoreCUPPO.Domain.Entities;

namespace ApiCoreCUPPO.Application.Interfaces.IRepository.Security
{
    public interface ISecurityRepository
    {
        // ---------- Usuarios
        Task<SpResultDto> InsertUserAsync(RegisterUserDto dto, string passwordBcrypt);
        Task<User?> GetUserByIdAsync(int userId);
        Task<SpResultDto> UpdateUserAsync(UpdateUserDto dto);

        // ---------- Inicio de sesión
        Task<UserLoginDataDto?> GetUserForLoginAsync(string identifier);
        Task<SpResultDto> RegisterLoginAttemptAsync(int userId, bool success);

        /// <summary>Valida contra el hash anterior (SHA-512 en SQL). Solo para usuarios aún no migrados a BCrypt.</summary>
        Task<SpResultDto> ValidateLegacyLoginAsync(string identifier, string password);
        Task<SpResultDto> SetUserPasswordAsync(int userId, string passwordBcrypt, bool revokeSessions, bool unblock);

        // ---------- Roles y permisos
        Task<IEnumerable<string>> GetUserRolesAsync(int userId);
        Task<IEnumerable<UserPermissionDto>> GetUserPermissionsAsync(int userId);
        Task<(bool HasPermission, SpResultDto Result)> ValidateUserPermissionAsync(CheckPermissionDto dto);

        // ---------- Sesiones (refresh tokens)
        Task<SpResultDto> InsertRefreshTokenAsync(int userId, byte[] tokenHash, DateTime expiresAt, string? deviceInfo);
        Task<SpResultDto> RotateRefreshTokenAsync(byte[] tokenHash, byte[] newTokenHash, DateTime newExpiresAt, string? deviceInfo);
        Task<SpResultDto> RevokeRefreshTokenAsync(byte[] tokenHash);

        // ---------- Recuperación de contraseña
        Task<SpResultDto> CreatePasswordResetCodeAsync(string mail, byte[] codeHash, DateTime expiresAt);
        Task<SpResultDto> ConsumePasswordResetCodeAsync(string mail, byte[] codeHash);
    }
}
