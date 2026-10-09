using ApiCoreCUPPO.API.Extensions;
using ApiCoreCUPPO.Application.DTOs.Venue;
using ApiCoreCUPPO.Application.Interfaces.IServices.Venue;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ApiCoreCUPPO.API.Controllers
{
    /// <summary>Solicitud para ser dueño de complejo, hecha por el propio usuario.</summary>
    [Authorize]
    [Route("api/[controller]")]
    public class OwnersController : ApiControllerBase
    {
        private readonly IOwnerService _ownerService;

        public OwnersController(IOwnerService ownerService)
        {
            _ownerService = ownerService;
        }

        /// <summary>Envía (o corrige) la solicitud para ser dueño. Queda pendiente hasta que CUPPO la revise.</summary>
        [HttpPost("me/verification")]
        public async Task<IActionResult> RequestVerification([FromBody] OwnerVerificationRequestDto request)
        {
            var result = await _ownerService.RequestVerificationAsync(User.GetUserId(), request);
            return FromSpResult(result);
        }

        /// <summary>Sube la foto de la cédula o RIF (JPG, PNG o WEBP, máximo 5 MB). Es privada: solo la ve CUPPO.</summary>
        [HttpPost("me/document")]
        [Consumes("multipart/form-data")]
        [RequestSizeLimit(UploadLimits.MaxRequestBytes)]
        public async Task<IActionResult> UploadDocument(IFormFile file)
        {
            await using var stream = file.OpenReadStream();
            return FromSpResult(await _ownerService.UploadDocumentAsync(User.GetUserId(), file.ToUploadDto(stream)));
        }

        /// <summary>Estado de la solicitud de dueño del usuario autenticado.</summary>
        [HttpGet("me")]
        public async Task<IActionResult> GetMyProfile()
        {
            var profile = await _ownerService.GetOwnerProfileAsync(User.GetUserId());
            return profile is null
                ? NotFound(new { code = 0, message = "Aún no has solicitado ser dueño de un complejo." })
                : Ok(profile);
        }
    }
}
