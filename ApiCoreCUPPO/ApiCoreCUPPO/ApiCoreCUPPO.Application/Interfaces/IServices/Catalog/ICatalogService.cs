using ApiCoreCUPPO.Application.DTOs.Catalog;
using ApiCoreCUPPO.Application.DTOs.Common;

namespace ApiCoreCUPPO.Application.Interfaces.IServices.Catalog
{
    public interface ICatalogService
    {
        Task<CatalogsDto> GetCatalogsAsync();
        Task<ExchangeRateDto?> GetLatestExchangeRateAsync();
        Task<SpResultDto> UpsertExchangeRateAsync(UpsertExchangeRateDto dto);
    }
}
