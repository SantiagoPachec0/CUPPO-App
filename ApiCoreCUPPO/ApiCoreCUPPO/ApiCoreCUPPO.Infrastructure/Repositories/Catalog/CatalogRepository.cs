using ApiCoreCUPPO.Application.DTOs.Catalog;
using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Catalog;
using ApiCoreCUPPO.Infrastructure.Data;
using Dapper;
using System.Data;

namespace ApiCoreCUPPO.Infrastructure.Repositories.Catalog
{
    public class CatalogRepository : ICatalogRepository
    {
        private readonly IDbConnectionFactory _db;

        public CatalogRepository(IDbConnectionFactory db)
        {
            _db = db;
        }

        public async Task<CatalogsDto> GetCatalogsAsync()
        {
            using var connection = _db.CreateConnection();
            using var grid = await connection.QueryMultipleAsync("[Catalog].[GetCatalogs]", commandType: CommandType.StoredProcedure);

            return new CatalogsDto
            {
                Sports = (await grid.ReadAsync<SportDto>()).ToList(),
                Surfaces = (await grid.ReadAsync<SurfaceDto>()).ToList(),
                Amenities = (await grid.ReadAsync<AmenityDto>()).ToList(),
                PaymentMethods = (await grid.ReadAsync<PaymentMethodDto>()).ToList(),
                States = (await grid.ReadAsync<StateDto>()).ToList(),
                Cities = (await grid.ReadAsync<CityDto>()).ToList(),
                Zones = (await grid.ReadAsync<ZoneDto>()).ToList()
            };
        }

        public async Task<ExchangeRateDto?> GetLatestExchangeRateAsync()
        {
            using var connection = _db.CreateConnection();
            return await connection.QueryFirstOrDefaultAsync<ExchangeRateDto>(
                "[Catalog].[GetLatestExchangeRate]", commandType: CommandType.StoredProcedure);
        }

        public async Task<SpResultDto> UpsertExchangeRateAsync(UpsertExchangeRateDto dto)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Catalog].[UpsertExchangeRate]", new
            {
                RateDate = dto.RateDate.Date,
                dto.RatePerUSD,
                dto.Source
            });
        }
    }
}
