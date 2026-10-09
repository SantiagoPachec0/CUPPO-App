using ApiCoreCUPPO.API.Authorization;
using ApiCoreCUPPO.API.Extensions;
using ApiCoreCUPPO.Application.DTOs.Security;
using ApiCoreCUPPO.Application.Interfaces.IServices.Security;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace ApiCoreCUPPO.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly IAuthService _authService;

        public AuthController(IAuthService authService)
        {
            _authService = authService;
        }

        [HttpPost("register")]
        [EnableRateLimiting(RateLimitPolicies.Auth)]
        public async Task<IActionResult> Register([FromBody] RegisterUserDto request)
        {
            var (isSuccess, data, message) = await _authService.RegisterAsync(request, HttpContext.GetDeviceInfo());

            if (!isSuccess)
                return BadRequest(new { code = -1, message });

            return Ok(data);
        }

        [HttpPost("login")]
        [EnableRateLimiting(RateLimitPolicies.Auth)]
        public async Task<IActionResult> Login([FromBody] LoginRequestDto request)
        {
            var (isSuccess, data, message) = await _authService.LoginAsync(request, HttpContext.GetDeviceInfo());

            if (!isSuccess)
                return Unauthorized(new { code = -1, message });

            return Ok(data);
        }

        /// <summary>Renueva la sesión: entrega un token de acceso nuevo y rota el refresh token.</summary>
        [HttpPost("refresh")]
        public async Task<IActionResult> Refresh([FromBody] RefreshTokenRequestDto request)
        {
            var (isSuccess, data, message) = await _authService.RefreshAsync(request.RefreshToken, HttpContext.GetDeviceInfo());

            if (!isSuccess)
                return Unauthorized(new { code = -1, message });

            return Ok(data);
        }

        /// <summary>Cierra la sesión de este dispositivo.</summary>
        [HttpPost("logout")]
        public async Task<IActionResult> Logout([FromBody] RefreshTokenRequestDto request)
        {
            await _authService.LogoutAsync(request.RefreshToken);
            return Ok(new { code = 1, message = "Sesión cerrada." });
        }

        /// <summary>Envía un código de 6 dígitos al correo para restablecer la contraseña.</summary>
        [HttpPost("forgot-password")]
        [EnableRateLimiting(RateLimitPolicies.Auth)]
        public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordDto request)
        {
            var message = await _authService.ForgotPasswordAsync(request);
            return Ok(new { code = 1, message });
        }

        [HttpPost("reset-password")]
        [EnableRateLimiting(RateLimitPolicies.Auth)]
        public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordDto request)
        {
            var result = await _authService.ResetPasswordAsync(request);

            if (!result.IsSuccess)
                return BadRequest(new { code = result.CodeResult, message = result.MessageResult });

            return Ok(new { code = 1, message = result.MessageResult });
        }
    }
}
