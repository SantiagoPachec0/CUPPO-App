using ApiCoreCUPPO.Application.DTOs.Venue;
using ApiCoreCUPPO.Application.Interfaces.IServices.Venue;
using Microsoft.AspNetCore.Mvc;

namespace ApiCoreCUPPO.API.Controllers
{
    /// <summary>Búsqueda y ficha de complejos (públicos, no requieren sesión).</summary>
    [Route("api/[controller]")]
    public class VenuesController : ApiControllerBase
    {
        private readonly IPublicVenueService _venueService;

        public VenuesController(IPublicVenueService venueService)
        {
            _venueService = venueService;
        }

        /// <summary>
        /// Busca complejos por deporte, ciudad, zona o texto. Si se envían latitude y longitude,
        /// ordena por distancia e incluye distanceKm.
        /// </summary>
        [HttpGet]
        public async Task<IActionResult> Search([FromQuery] VenueSearchQueryDto query)
        {
            return Ok(await _venueService.SearchAsync(query));
        }

        /// <summary>Ficha del complejo: fotos, comodidades, canchas con rango de precios y métodos de pago aceptados.</summary>
        [HttpGet("{venueId:int}")]
        public async Task<IActionResult> GetVenue(int venueId)
        {
            var venue = await _venueService.GetVenueAsync(venueId);
            return venue is null ? NotFound(new { code = 0, message = "El complejo no existe o no está disponible." }) : Ok(venue);
        }
    }
}
