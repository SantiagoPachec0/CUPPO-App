using ApiCoreCUPPO.Application.DTOs.Catalog;
using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Catalog;
using ApiCoreCUPPO.Application.Interfaces.IServices.Catalog;
using Microsoft.Extensions.Caching.Memory;

namespace ApiCoreCUPPO.Application.Services.Catalog
{
    public class CatalogService : ICatalogService
    {
        private const string CatalogsCacheKey = "catalogs";
        private const string ExchangeRateCacheKey = "exchange-rate";
        private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(10);

        private readonly ICatalogRepository _catalogRepository;
        private readonly IMemoryCache _cache;

        public CatalogService(ICatalogRepository catalogRepository, IMemoryCache cache)
        {
            _catalogRepository = catalogRepository;
            _cache = cache;
        }

        public async Task<CatalogsDto> GetCatalogsAsync()
        {
            return (await _cache.GetOrCreateAsync(CatalogsCacheKey, entry =>
            {
                entry.AbsoluteExpirationRelativeToNow = CacheDuration;
                return _catalogRepository.GetCatalogsAsync();
            }))!;
        }

        public async Task<ExchangeRateDto?> GetLatestExchangeRateAsync()
        {
            return await _cache.GetOrCreateAsync(ExchangeRateCacheKey, entry =>
            {
                entry.AbsoluteExpirationRelativeToNow = CacheDuration;
                return _catalogRepository.GetLatestExchangeRateAsync();
            });
        }

        public async Task<SpResultDto> UpsertExchangeRateAsync(UpsertExchangeRateDto dto)
        {
            var result = await _catalogRepository.UpsertExchangeRateAsync(dto);
            if (result.IsSuccess)
                _cache.Remove(ExchangeRateCacheKey);

            return result;
        }
    }
}
