using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Data;

namespace ApiCoreCUPPO.Infrastructure.Data
{
    public interface IDbConnectionFactory
    {
        IDbConnection CreateConnection();
    }

    public class SqlConnectionFactory : IDbConnectionFactory
    {
        private readonly string _connectionString;

        public SqlConnectionFactory(IConfiguration configuration)
        {
            var connectionString = configuration.GetConnectionString("DefaultConnection");
            _connectionString = !string.IsNullOrWhiteSpace(connectionString)
                ? connectionString
                : throw new InvalidOperationException("La cadena de conexión 'DefaultConnection' no está configurada.");
        }

        public IDbConnection CreateConnection() => new SqlConnection(_connectionString);
    }
}
