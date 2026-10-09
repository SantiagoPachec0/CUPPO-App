using ApiCoreCUPPO.API.Authorization;
using ApiCoreCUPPO.API.Extensions;
using ApiCoreCUPPO.Application.DTOs.Venue;
using ApiCoreCUPPO.Application.Interfaces.IServices.Venue;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ApiCoreCUPPO.API.Controllers
{
    /// <summary>Panel de dueño: mis complejos, comodidades, cuentas de cobro y fotos.</summary>
    [Authorize(Policy = Policies.VerifiedOwner)]
    [Route("api/owner/venues")]
    public class OwnerVenuesController : ApiControllerBase
    {
        private readonly IVenueManagementService _venueService;

        public OwnerVenuesController(IVenueManagementService venueService)
        {
            _venueService = venueService;
        }

        [HttpGet]
        public async Task<IActionResult> GetMyVenues()
        {
            return Ok(await _venueService.GetOwnerVenuesAsync(User.GetUserId()));
        }

        /// <summary>Ficha completa: datos, fotos, comodidades y cuentas de cobro.</summary>
        [HttpGet("{venueId:int}")]
        public async Task<IActionResult> GetVenue(int venueId)
        {
            var venue = await _venueService.GetVenueForOwnerAsync(venueId, User.GetUserId());
            return venue is null ? NotFound(new { code = 0, message = "El complejo no existe o no es tuyo." }) : Ok(venue);
        }

        /// <summary>Registra un complejo. Queda pendiente hasta que CUPPO lo apruebe.</summary>
        [HttpPost]
        public async Task<IActionResult> CreateVenue([FromBody] VenueUpsertDto request)
        {
            return FromSpResult(await _venueService.CreateVenueAsync(User.GetUserId(), request));
        }

        [HttpPut("{venueId:int}")]
        public async Task<IActionResult> UpdateVenue(int venueId, [FromBody] VenueUpsertDto request)
        {
            return FromSpResult(await _venueService.UpdateVenueAsync(venueId, User.GetUserId(), request));
        }

        /// <summary>1 activo, 2 pausado (oculto y sin reservas).</summary>
        [HttpPut("{venueId:int}/status")]
        public async Task<IActionResult> SetStatus(int venueId, [FromBody] StatusDto request)
        {
            return FromSpResult(await _venueService.SetVenueStatusAsync(venueId, User.GetUserId(), request.StatusID));
        }

        /// <summary>Reemplaza las comodidades del complejo.</summary>
        [HttpPut("{venueId:int}/amenities")]
        public async Task<IActionResult> SetAmenities(int venueId, [FromBody] AmenityIdsDto request)
        {
            return FromSpResult(await _venueService.SetVenueAmenitiesAsync(venueId, User.GetUserId(), request.AmenityIDs));
        }

        // ---------- Cuentas de cobro

        [HttpPost("{venueId:int}/payment-accounts")]
        public async Task<IActionResult> CreatePaymentAccount(int venueId, [FromBody] PaymentAccountUpsertDto request)
        {
            return FromSpResult(await _venueService.UpsertPaymentAccountAsync(null, venueId, User.GetUserId(), request));
        }

        [HttpPut("{venueId:int}/payment-accounts/{accountId:int}")]
        public async Task<IActionResult> UpdatePaymentAccount(int venueId, int accountId, [FromBody] PaymentAccountUpsertDto request)
        {
            return FromSpResult(await _venueService.UpsertPaymentAccountAsync(accountId, venueId, User.GetUserId(), request));
        }

        /// <summary>1 activa, 2 inactiva, 3 eliminada.</summary>
        [HttpPut("{venueId:int}/payment-accounts/{accountId:int}/status")]
        public async Task<IActionResult> SetPaymentAccountStatus(int venueId, int accountId, [FromBody] StatusDto request)
        {
            return FromSpResult(await _venueService.SetPaymentAccountStatusAsync(accountId, User.GetUserId(), request.StatusID));
        }

        // ---------- Fotos

        /// <summary>Sube una foto (JPG, PNG o WEBP, máximo 5 MB, hasta 10 por complejo).</summary>
        [HttpPost("{venueId:int}/photos")]
        [Consumes("multipart/form-data")]
        [RequestSizeLimit(UploadLimits.MaxRequestBytes)]
        public async Task<IActionResult> UploadPhoto(int venueId, IFormFile file)
        {
            await using var stream = file.OpenReadStream();
            return FromSpResult(await _venueService.AddVenuePhotoAsync(venueId, User.GetUserId(), file.ToUploadDto(stream)));
        }

        [HttpDelete("{venueId:int}/photos/{photoId:int}")]
        public async Task<IActionResult> DeletePhoto(int venueId, int photoId)
        {
            return FromSpResult(await _venueService.DeleteVenuePhotoAsync(photoId, User.GetUserId()));
        }

        [HttpPut("{venueId:int}/photos/{photoId:int}/cover")]
        public async Task<IActionResult> SetCoverPhoto(int venueId, int photoId)
        {
            return FromSpResult(await _venueService.SetVenueCoverPhotoAsync(photoId, User.GetUserId()));
        }
    }
}
