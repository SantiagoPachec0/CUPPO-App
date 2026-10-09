using ApiCoreCUPPO.Application.DTOs.Common;
using Microsoft.AspNetCore.Mvc;

namespace ApiCoreCUPPO.API.Controllers
{
    [ApiController]
    public abstract class ApiControllerBase : ControllerBase
    {
        /// <summary>
        /// Convierte el resultado de un stored procedure en la respuesta HTTP:
        /// CodeResult &gt; 0 → 200; -403 (sin permiso sobre el recurso) → 403; -1 (error interno de SQL,
        /// ya registrado en Log.ErrorLog) → 500 con mensaje genérico; cualquier otro → 400 con el
        /// mensaje de negocio del SP.
        /// </summary>
        protected IActionResult FromSpResult(SpResultDto result, object? data = null)
        {
            if (result.IsSuccess)
                return Ok(new { code = result.CodeResult, message = result.MessageResult, data });

            if (result.CodeResult == -403)
                return StatusCode(StatusCodes.Status403Forbidden, new { code = -403, message = result.MessageResult });

            if (result.CodeResult == -1)
                return StatusCode(StatusCodes.Status500InternalServerError,
                    new { code = -1, message = "Ocurrió un error inesperado. Intenta de nuevo." });

            return BadRequest(new { code = result.CodeResult, message = result.MessageResult });
        }
    }
}
