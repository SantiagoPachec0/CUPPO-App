using ApiCoreCUPPO.Application.Interfaces.IServices.Catalog;
using Microsoft.AspNetCore.Mvc;

namespace ApiCoreCUPPO.API.Controllers
{
    /// <summary>Catálogos públicos (no requieren sesión).</summary>
    [Route("api/[controller]")]
    public class CatalogController : ApiControllerBase
    {
        private readonly ICatalogService _catalogService;

        public CatalogController(ICatalogService catalogService)
        {
            _catalogService = catalogService;
        }

        /// <summary>Deportes, superficies, comodidades, métodos de pago y ubicaciones en una sola llamada.</summary>
        [HttpGet]
        public async Task<IActionResult> GetCatalogs()
        {
            return Ok(await _catalogService.GetCatalogsAsync());
        }

        /// <summary>Tasa BCV vigente (bolívares por dólar).</summary>
        [HttpGet("exchange-rate")]
        public async Task<IActionResult> GetExchangeRate()
        {
            var rate = await _catalogService.GetLatestExchangeRateAsync();
            return rate is null ? NotFound(new { code = 0, message = "No hay tasa registrada." }) : Ok(rate);
        }
    }
}
