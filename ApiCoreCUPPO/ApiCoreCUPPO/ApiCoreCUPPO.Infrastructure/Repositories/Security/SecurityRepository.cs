using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Security;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Security;
using ApiCoreCUPPO.Domain.Entities;
using ApiCoreCUPPO.Infrastructure.Data;
using Dapper;
using System.Data;

namespace ApiCoreCUPPO.Infrastructure.Repositories.Security
{
    public class SecurityRepository : ISecurityRepository
    {
        private readonly IDbConnectionFactory _db;

        public SecurityRepository(IDbConnectionFactory db)
        {
            _db = db;
        }

        // ---------- Usuarios

        public async Task<SpResultDto> InsertUserAsync(RegisterUserDto dto, string passwordBcrypt)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Security].[InsertUser]", new
            {
                dto.UserLogin,
                dto.Name,
                dto.Mail,
                PasswordBcrypt = passwordBcrypt,
                dto.CreationUserID
            });
        }

        public async Task<User?> GetUserByIdAsync(int userId)
        {
            using var connection = _db.CreateConnection();
            const string sql = @"
                SELECT [UserID], [UserLogin], [Name], [Mail], [PasswordHash], [PasswordSalt], [PasswordBcrypt],
                       [Blocked], [FailedLoginAttempts], [StatusID], [CreationUserID],
                       [UpdateUserID], [CreationDate], [UpdateDate]
                FROM [Security].[Users]
                WHERE [UserID] = @UserID;";

            return await connection.QueryFirstOrDefaultAsync<User>(sql, new { UserID = userId });
        }

        public async Task<SpResultDto> UpdateUserAsync(UpdateUserDto dto)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Security].[UpdateUser]", new
            {
                dto.UserID,
                dto.UserLogin,
                dto.Name,
                dto.Mail,
                dto.Blocked,
                dto.FailedLoginAttempts,
                dto.StatusID,
                dto.UpdateUserID
            });
        }

        // ---------- Inicio de sesión

        public async Task<UserLoginDataDto?> GetUserForLoginAsync(string identifier)
        {
            using var connection = _db.CreateConnection();
            return await connection.QueryFirstOrDefaultAsync<UserLoginDataDto>(
                "[Security].[GetUserForLogin]",
                new { Identifier = identifier },
                commandType: CommandType.StoredProcedure);
        }

        public async Task<SpResultDto> RegisterLoginAttemptAsync(int userId, bool success)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Security].[RegisterLoginAttempt]", new { UserID = userId, Success = success });
        }

        public async Task<SpResultDto> ValidateLegacyLoginAsync(string identifier, string password)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Security].[ValidateUserLogin]", new { Identifier = identifier, Password = password });
        }

        public async Task<SpResultDto> SetUserPasswordAsync(int userId, string passwordBcrypt, bool revokeSessions, bool unblock)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Security].[SetUserPassword]", new
            {
                UserID = userId,
                PasswordBcrypt = passwordBcrypt,
                RevokeSessions = revokeSessions,
                Unblock = unblock
            });
        }

        // ---------- Roles y permisos

        public async Task<IEnumerable<string>> GetUserRolesAsync(int userId)
        {
            using var connection = _db.CreateConnection();
            return await connection.QueryAsync<string>(
                "[Security].[GetUserRoles]",
                new { UserID = userId },
                commandType: CommandType.StoredProcedure);
        }

        public async Task<IEnumerable<UserPermissionDto>> GetUserPermissionsAsync(int userId)
        {
            using var connection = _db.CreateConnection();
            return await connection.QueryAsync<UserPermissionDto>(
                "[Security].[GetUserPermissions]",
                new { UserID = userId },
                commandType: CommandType.StoredProcedure);
        }

        public async Task<(bool HasPermission, SpResultDto Result)> ValidateUserPermissionAsync(CheckPermissionDto dto)
        {
            using var connection = _db.CreateConnection();
            var parameters = new DynamicParameters(new { dto.UserID, dto.ModuleCode, dto.ActionCode });
            parameters.Add("@HasPermission", dbType: DbType.Boolean, direction: ParameterDirection.Output);

            var result = await connection.ExecuteSpAsync("[Security].[ValidateUserPermission]", parameters);
            return (parameters.Get<bool?>("@HasPermission") ?? false, result);
        }

        // ---------- Sesiones (refresh tokens)

        public async Task<SpResultDto> InsertRefreshTokenAsync(int userId, byte[] tokenHash, DateTime expiresAt, string? deviceInfo)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Security].[InsertRefreshToken]", new
            {
                UserID = userId,
                TokenHash = tokenHash,
                ExpiresAt = expiresAt,
                DeviceInfo = deviceInfo
            });
        }

        public async Task<SpResultDto> RotateRefreshTokenAsync(byte[] tokenHash, byte[] newTokenHash, DateTime newExpiresAt, string? deviceInfo)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Security].[RotateRefreshToken]", new
            {
                TokenHash = tokenHash,
                NewTokenHash = newTokenHash,
                NewExpiresAt = newExpiresAt,
                DeviceInfo = deviceInfo
            });
        }

        public async Task<SpResultDto> RevokeRefreshTokenAsync(byte[] tokenHash)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Security].[RevokeRefreshToken]", new { TokenHash = tokenHash });
        }

        // ---------- Recuperación de contraseña

        public async Task<SpResultDto> CreatePasswordResetCodeAsync(string mail, byte[] codeHash, DateTime expiresAt)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Security].[CreatePasswordResetCode]", new
            {
                Mail = mail,
                CodeHash = codeHash,
                ExpiresAt = expiresAt
            });
        }

        public async Task<SpResultDto> ConsumePasswordResetCodeAsync(string mail, byte[] codeHash)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Security].[ConsumePasswordResetCode]", new
            {
                Mail = mail,
                CodeHash = codeHash
            });
        }
    }
}
