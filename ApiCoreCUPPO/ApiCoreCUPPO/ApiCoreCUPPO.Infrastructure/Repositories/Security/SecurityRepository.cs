using ApiCoreCUPPO.Application.DTOs.Security;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Security;
using ApiCoreCUPPO.Domain.Entities;
using Microsoft.Extensions.Configuration;
using Dapper;
using Microsoft.Data.SqlClient;
using System.Data;
using ApiCoreCUPPO.Application.Interfaces.IServices.Security;

namespace ApiCoreCUPPO.Infrastructure.Repositories.Security
{
    public class SecurityRepository : ISecurityRepository
    {
        private readonly string _connectionString;

        public SecurityRepository(IConfiguration configuration)
        {
            var connectionString = configuration.GetConnectionString("DefaultConnection");
            _connectionString = !string.IsNullOrWhiteSpace(connectionString)
                ? connectionString
                : throw new InvalidOperationException("La cadena de conexión 'DefaultConnection' no está configurada.");
        }

        private IDbConnection CreateConnection() => new SqlConnection(_connectionString);

        public async Task<SpResultDto> InsertUserAsync(RegisterUserDto dto)
        {
            using var connection = CreateConnection();
            var parameters = new DynamicParameters();

            parameters.Add("@UserLogin", dto.UserLogin, DbType.String);
            parameters.Add("@Name", dto.Name, DbType.String);
            parameters.Add("@Mail", dto.Mail, DbType.String);
            parameters.Add("@Password", dto.Password, DbType.String);
            parameters.Add("@Blocked", false, DbType.Boolean);
            parameters.Add("@FailedLoginAttempts", 0, DbType.Int32);
            parameters.Add("@StatusID", 1, DbType.Int32);
            parameters.Add("@CreationUserID", dto.CreationUserID, DbType.Int32);

            parameters.Add("@CodeResult", dbType: DbType.Int32, direction: ParameterDirection.Output);
            parameters.Add("@MessageResult", dbType: DbType.String, size: -1, direction: ParameterDirection.Output);

            await connection.ExecuteAsync(
                "[Security].[InsertUser]",
                parameters,
                commandType: CommandType.StoredProcedure
            );

            return new SpResultDto
            {
                CodeResult = parameters.Get<int>("@CodeResult"),
                MessageResult = parameters.Get<string>("@MessageResult") ?? string.Empty
            };
        }

        public async Task<SpResultDto> ValidateUserLoginAsync(LoginRequestDto dto)
        {
            using var connection = CreateConnection();
            var parameters = new DynamicParameters();

            parameters.Add("@Identifier", dto.Identifier, DbType.String);
            parameters.Add("@Password", dto.Password, DbType.String);

            parameters.Add("@CodeResult", dbType: DbType.Int32, direction: ParameterDirection.Output);
            parameters.Add("@MessageResult", dbType: DbType.String, size: -1, direction: ParameterDirection.Output);

            await connection.ExecuteAsync(
                "[Security].[ValidateUserLogin]",
                parameters,
                commandType: CommandType.StoredProcedure
            );

            return new SpResultDto
            {
                CodeResult = parameters.Get<int>("@CodeResult"),
                MessageResult = parameters.Get<string>("@MessageResult") ?? string.Empty
            };
        }

        public async Task<SpResultDto> UpdateUserAsync(UpdateUserDto dto)
        {
            using var connection = CreateConnection();
            var parameters = new DynamicParameters();

            parameters.Add("@UserID", dto.UserID, DbType.Int32);
            parameters.Add("@UserLogin", dto.UserLogin, DbType.String);
            parameters.Add("@Name", dto.Name, DbType.String);
            parameters.Add("@Mail", dto.Mail, DbType.String);
            parameters.Add("@Blocked", dto.Blocked, DbType.Boolean);
            parameters.Add("@FailedLoginAttempts", dto.FailedLoginAttempts, DbType.Int32);
            parameters.Add("@StatusID", dto.StatusID, DbType.Int32);
            parameters.Add("@UpdateUserID", dto.UpdateUserID, DbType.Int32);

            parameters.Add("@CodeResult", dbType: DbType.Int32, direction: ParameterDirection.Output);
            parameters.Add("@MessageResult", dbType: DbType.String, size: -1, direction: ParameterDirection.Output);

            await connection.ExecuteAsync(
                "[Security].[UpdateUser]",
                parameters,
                commandType: CommandType.StoredProcedure
            );

            return new SpResultDto
            {
                CodeResult = parameters.Get<int>("@CodeResult"),
                MessageResult = parameters.Get<string>("@MessageResult") ?? string.Empty
            };
        }

        public async Task<User?> GetUserByIdAsync(int userId)
        {
            using var connection = CreateConnection();
            string sql = @"
                SELECT [UserID], [UserLogin], [Name], [Mail], [PasswordHash], [PasswordSalt], 
                       [Blocked], [FailedLoginAttempts], [StatusID], [CreationUserID], 
                       [UpdateUserID], [CreationDate], [UpdateDate]
                FROM [Security].[Users]
                WHERE [UserID] = @UserID;";

            return await connection.QueryFirstOrDefaultAsync<User>(sql, new { UserID = userId });
        }

        public async Task<IEnumerable<UserPermissionDto>> GetUserPermissionsAsync(int userId)
        {
            using var connection = CreateConnection();

            return await connection.QueryAsync<UserPermissionDto>(
                "[Security].[GetUserPermissions]",
                new { UserID = userId },
                commandType: CommandType.StoredProcedure
            );
        }

        public async Task<(bool HasPermission, SpResultDto Result)> ValidateUserPermissionAsync(CheckPermissionDto dto)
        {
            using var connection = CreateConnection();
            var parameters = new DynamicParameters();

            parameters.Add("@UserID", dto.UserID, DbType.Int32);
            parameters.Add("@ModuleCode", dto.ModuleCode, DbType.String);
            parameters.Add("@ActionCode", dto.ActionCode, DbType.String);

            parameters.Add("@HasPermission", dbType: DbType.Boolean, direction: ParameterDirection.Output);
            parameters.Add("@CodeResult", dbType: DbType.Int32, direction: ParameterDirection.Output);
            parameters.Add("@MessageResult", dbType: DbType.String, size: -1, direction: ParameterDirection.Output);

            await connection.ExecuteAsync(
                "[Security].[ValidateUserPermission]",
                parameters,
                commandType: CommandType.StoredProcedure
            );

            bool hasPermission = parameters.Get<bool>("@HasPermission");
            var result = new SpResultDto
            {
                CodeResult = parameters.Get<int>("@CodeResult"),
                MessageResult = parameters.Get<string>("@MessageResult") ?? string.Empty
            };

            return (hasPermission, result);
        }
    }
}