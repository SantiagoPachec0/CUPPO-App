using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Security;

namespace ApiCoreCUPPO.Application.Interfaces.IServices.Security
{
    public interface IAuthService
    {
        Task<(bool IsSuccess, AuthResponseDto? Data, string Message)> RegisterAsync(RegisterUserDto dto, string? deviceInfo);
        Task<(bool IsSuccess, AuthResponseDto? Data, string Message)> LoginAsync(LoginRequestDto dto, string? deviceInfo);
        Task<(bool IsSuccess, AuthResponseDto? Data, string Message)> RefreshAsync(string refreshToken, string? deviceInfo);
        Task LogoutAsync(string refreshToken);
        Task<(bool IsSuccess, AuthResponseDto? Data, string Message)> ChangePasswordAsync(int userId, ChangePasswordDto dto, string? deviceInfo);

        /// <summary>Siempre responde lo mismo, exista o no el correo, para no revelar qué correos están registrados.</summary>
        Task<string> ForgotPasswordAsync(ForgotPasswordDto dto);
        Task<SpResultDto> ResetPasswordAsync(ResetPasswordDto dto);
    }
}
