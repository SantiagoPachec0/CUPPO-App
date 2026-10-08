using ApiCoreCUPPO.Application.DTOs.Security;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Security;
using ApiCoreCUPPO.Application.Interfaces.IServices.Security;
using ApiCoreCUPPO.Infrastructure.Utilities.Authentication;
using Microsoft.AspNetCore.Mvc;

namespace ApiCoreCUPPO.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly ISecurityService _securityService;

        public AuthController(ISecurityService securityService)
        {
            _securityService = securityService;
        }

        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] RegisterUserDto request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var (isSuccess, data, message) = await _securityService.RegisterAsync(request);

            if (!isSuccess)
                return BadRequest(new { code = -1, message });

            return Ok(data);
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginRequestDto request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var (isSuccess, data, message) = await _securityService.LoginAsync(request);

            if (!isSuccess)
                return Unauthorized(new { code = -1, message });

            return Ok(data);
        }
    }
}