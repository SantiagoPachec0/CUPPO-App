using ApiCoreCUPPO.API.Authorization;
using ApiCoreCUPPO.API.Extensions;
using ApiCoreCUPPO.Application.DTOs.Venue;
using ApiCoreCUPPO.Application.Interfaces.IServices.Venue;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ApiCoreCUPPO.API.Controllers
{
    /// <summary>Panel de dueño: canchas, horarios, precios, bloqueos y fotos de canchas.</summary>
    [Authorize(Policy = Policies.VerifiedOwner)]
    [Route("api/owner")]
    public class OwnerCourtsController : ApiControllerBase
    {
        private readonly ICourtManagementService _courtService;

        public OwnerCourtsController(ICourtManagementService courtService)
        {
            _courtService = courtService;
        }

        /// <summary>Canchas del complejo con horario, precios y fotos.</summary>
        [HttpGet("venues/{venueId:int}/courts")]
        public async Task<IActionResult> GetCourts(int venueId)
        {
            return Ok(await _courtService.GetCourtsAsync(venueId, User.GetUserId()));
        }

        [HttpPost("venues/{venueId:int}/courts")]
        public async Task<IActionResult> CreateCourt(int venueId, [FromBody] CourtUpsertDto request)
        {
            return FromSpResult(await _courtService.CreateCourtAsync(venueId, User.GetUserId(), request));
        }

        [HttpPut("courts/{courtId:int}")]
        public async Task<IActionResult> UpdateCourt(int courtId, [FromBody] CourtUpsertDto request)
        {
            return FromSpResult(await _courtService.UpdateCourtAsync(courtId, User.GetUserId(), request));
        }

        /// <summary>1 activa, 2 inactiva, 3 eliminada. No se permite con reservas futuras.</summary>
        [HttpPut("courts/{courtId:int}/status")]
        public async Task<IActionResult> SetStatus(int courtId, [FromBody] StatusDto request)
        {
            return FromSpResult(await _courtService.SetCourtStatusAsync(courtId, User.GetUserId(), request.StatusID));
        }

        /// <summary>Reemplaza el horario semanal. dayOfWeek 1 lunes ... 7 domingo; closeTime "00:00" = medianoche.</summary>
        [HttpPut("courts/{courtId:int}/schedule")]
        public async Task<IActionResult> SetSchedule(int courtId, [FromBody] List<ScheduleItemDto> request)
        {
            return FromSpResult(await _courtService.SetScheduleAsync(courtId, User.GetUserId(), request));
        }

        /// <summary>Reemplaza las tarifas por hora (USD). dayOfWeek null = todos los días.</summary>
        [HttpPut("courts/{courtId:int}/prices")]
        public async Task<IActionResult> SetPrices(int courtId, [FromBody] List<PriceItemDto> request)
        {
            return FromSpResult(await _courtService.SetPricesAsync(courtId, User.GetUserId(), request));
        }

        // ---------- Bloqueos

        /// <summary>Bloqueos del complejo entre dos fechas (hora local; máximo 62 días).</summary>
        [HttpGet("venues/{venueId:int}/blocks")]
        public async Task<IActionResult> GetBlocks(int venueId, [FromQuery] DateTime from, [FromQuery] DateTime to)
        {
            return Ok(await _courtService.GetBlocksAsync(venueId, User.GetUserId(), from, to));
        }

        [HttpPost("courts/{courtId:int}/blocks")]
        public async Task<IActionResult> CreateBlock(int courtId, [FromBody] CourtBlockCreateDto request)
        {
            return FromSpResult(await _courtService.CreateBlockAsync(courtId, User.GetUserId(), request));
        }

        [HttpDelete("blocks/{blockId:int}")]
        public async Task<IActionResult> DeleteBlock(int blockId)
        {
            return FromSpResult(await _courtService.DeleteBlockAsync(blockId, User.GetUserId()));
        }

        // ---------- Fotos

        /// <summary>Sube una foto de la cancha (JPG, PNG o WEBP, máximo 5 MB, hasta 5 por cancha).</summary>
        [HttpPost("courts/{courtId:int}/photos")]
        [Consumes("multipart/form-data")]
        [RequestSizeLimit(UploadLimits.MaxRequestBytes)]
        public async Task<IActionResult> UploadPhoto(int courtId, IFormFile file)
        {
            await using var stream = file.OpenReadStream();
            return FromSpResult(await _courtService.AddCourtPhotoAsync(courtId, User.GetUserId(), file.ToUploadDto(stream)));
        }

        [HttpDelete("courts/photos/{photoId:int}")]
        public async Task<IActionResult> DeletePhoto(int photoId)
        {
            return FromSpResult(await _courtService.DeleteCourtPhotoAsync(photoId, User.GetUserId()));
        }
    }
}
