using ApiCoreCUPPO.Application.DTOs.Catalog;
using ApiCoreCUPPO.Application.DTOs.Common;

namespace ApiCoreCUPPO.Application.Interfaces.IRepository.Catalog
{
    public interface ICatalogRepository
    {
        Task<CatalogsDto> GetCatalogsAsync();
        Task<ExchangeRateDto?> GetLatestExchangeRateAsync();
        Task<SpResultDto> UpsertExchangeRateAsync(UpsertExchangeRateDto dto);
    }
}
