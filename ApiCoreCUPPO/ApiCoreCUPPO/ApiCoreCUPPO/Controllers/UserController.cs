using ApiCoreCUPPO.API.Extensions;
using ApiCoreCUPPO.Application.DTOs.Security;
using ApiCoreCUPPO.Application.Interfaces.IServices.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ApiCoreCUPPO.API.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class UsersController : ControllerBase
    {
        private readonly ISecurityService _securityService;

        public UsersController(ISecurityService securityService)
        {
            _securityService = securityService;
        }

        /// <summary>
        /// Actualiza los datos del usuario autenticado. Los campos administrativos
        /// (bloqueo, intentos fallidos, estado) no se pueden modificar desde aquí.
        /// </summary>
        [HttpPut("me")]
        public async Task<IActionResult> UpdateUser([FromBody] UpdateUserDto request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var currentUserId = User.GetUserId();
            request.UserID = currentUserId;
            request.UpdateUserID = currentUserId;
            request.Blocked = null;
            request.FailedLoginAttempts = null;
            request.StatusID = null;

            var result = await _securityService.UpdateUserAsync(request);

            if (!result.IsSuccess)
            {
                return BadRequest(new { code = result.CodeResult, message = result.MessageResult });
            }

            return Ok(new { code = result.CodeResult, message = result.MessageResult });
        }

        [HttpGet("me/permissions")]
        public async Task<IActionResult> GetPermissions()
        {
            var permissions = await _securityService.GetUserPermissionsAsync(User.GetUserId());
            return Ok(permissions);
        }

        [HttpPost("me/check-permission")]
        public async Task<IActionResult> CheckPermission([FromBody] CheckPermissionDto request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            request.UserID = User.GetUserId();

            var (hasPermission, result) = await _securityService.ValidateUserPermissionAsync(request);

            return Ok(new
            {
                hasPermission,
                code = result.CodeResult,
                message = result.MessageResult
            });
        }
    }
}
