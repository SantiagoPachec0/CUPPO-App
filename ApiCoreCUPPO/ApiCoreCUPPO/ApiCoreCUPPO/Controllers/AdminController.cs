using ApiCoreCUPPO.API.Authorization;
using ApiCoreCUPPO.API.Extensions;
using ApiCoreCUPPO.Application.DTOs.Catalog;
using ApiCoreCUPPO.Application.DTOs.Venue;
using ApiCoreCUPPO.Application.Interfaces.IServices.Catalog;
using ApiCoreCUPPO.Application.Interfaces.IServices.Venue;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ApiCoreCUPPO.API.Controllers
{
    /// <summary>Herramientas internas de CUPPO (solo SUPERADMIN).</summary>
    [Authorize(Policy = Policies.SuperAdmin)]
    [Route("api/[controller]")]
    public class AdminController : ApiControllerBase
    {
        private readonly IOwnerService _ownerService;
        private readonly ICatalogService _catalogService;
        private readonly IVenueManagementService _venueService;

        public AdminController(IOwnerService ownerService, ICatalogService catalogService, IVenueManagementService venueService)
        {
            _ownerService = ownerService;
            _catalogService = catalogService;
            _venueService = venueService;
        }

        /// <summary>Solicitudes de dueño. statusId: 1 pendientes, 2 aprobadas, 3 rechazadas, 4 suspendidas; vacío = todas.</summary>
        [HttpGet("owner-requests")]
        public async Task<IActionResult> GetOwnerRequests([FromQuery] int? statusId)
        {
            return Ok(await _ownerService.GetOwnerRequestsAsync(statusId));
        }

        /// <summary>Aprueba (2), rechaza (3) o suspende (4) a un dueño. Rechazar y suspender exigen motivo.</summary>
        [HttpPut("owner-requests/{userId:int}")]
        public async Task<IActionResult> ReviewOwnerRequest(int userId, [FromBody] ReviewVerificationDto request)
        {
            var result = await _ownerService.ReviewVerificationAsync(userId, request, User.GetUserId());
            return FromSpResult(result);
        }

        /// <summary>Foto de la cédula o RIF que subió el dueño.</summary>
        [HttpGet("owner-requests/{userId:int}/document")]
        public async Task<IActionResult> GetOwnerDocument(int userId)
        {
            var document = await _ownerService.OpenDocumentAsync(userId);
            return document is null
                ? NotFound(new { code = 0, message = "El dueño no ha subido documento." })
                : File(document.Value.Content, document.Value.ContentType);
        }

        /// <summary>Complejos por revisar. statusId: 1 pendientes, 2 aprobados, 3 rechazados, 4 suspendidos; vacío = todos.</summary>
        [HttpGet("venue-requests")]
        public async Task<IActionResult> GetVenueRequests([FromQuery] int? statusId)
        {
            return Ok(await _venueService.GetVenueRequestsAsync(statusId));
        }

        /// <summary>Aprueba (2), rechaza (3) o suspende (4) un complejo. Al aprobarlo recibe el plan de prueba.</summary>
        [HttpPut("venue-requests/{venueId:int}")]
        public async Task<IActionResult> ReviewVenue(int venueId, [FromBody] ReviewVerificationDto request)
        {
            return FromSpResult(await _venueService.ReviewVenueAsync(venueId, request, User.GetUserId()));
        }

        /// <summary>Registra o corrige la tasa BCV de un día.</summary>
        [HttpPost("exchange-rates")]
        public async Task<IActionResult> UpsertExchangeRate([FromBody] UpsertExchangeRateDto request)
        {
            var result = await _catalogService.UpsertExchangeRateAsync(request);
            return FromSpResult(result);
        }
    }
}
