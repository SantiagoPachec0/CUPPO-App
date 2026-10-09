using ApiCoreCUPPO.Application.DTOs.Common;
using Dapper;
using System.Data;

namespace ApiCoreCUPPO.Infrastructure.Data
{
    public static class StoredProcedureExtensions
    {
        /// <summary>
        /// Ejecuta un stored procedure con la convención CUPPO: agrega los parámetros de salida
        /// @CodeResult y @MessageResult y los devuelve como <see cref="SpResultDto"/>.
        /// </summary>
        public static async Task<SpResultDto> ExecuteSpAsync(this IDbConnection connection, string procedure, DynamicParameters parameters)
        {
            parameters.Add("@CodeResult", dbType: DbType.Int32, direction: ParameterDirection.Output);
            parameters.Add("@MessageResult", dbType: DbType.String, size: -1, direction: ParameterDirection.Output);

            await connection.ExecuteAsync(procedure, parameters, commandType: CommandType.StoredProcedure);

            return new SpResultDto
            {
                CodeResult = parameters.Get<int?>("@CodeResult") ?? -1,
                MessageResult = parameters.Get<string>("@MessageResult") ?? string.Empty
            };
        }

        /// <summary>
        /// Igual que <see cref="ExecuteSpAsync"/> pero a partir de un objeto anónimo con los parámetros de entrada.
        /// </summary>
        public static Task<SpResultDto> ExecuteSpAsync(this IDbConnection connection, string procedure, object inputParameters)
            => connection.ExecuteSpAsync(procedure, new DynamicParameters(inputParameters));
    }
}
