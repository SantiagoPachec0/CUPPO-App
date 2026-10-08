using ApiCoreCUPPO.Application.DTOs.Security;
using System;
using System.Collections.Generic;
using System.Text;

namespace ApiCoreCUPPO.Application.Interfaces.IServices.Security
{
    public interface ISecurityService
    {
        Task<(bool IsSuccess, AuthResponseDto? Data, string Message)> RegisterAsync(RegisterUserDto dto);
        Task<(bool IsSuccess, AuthResponseDto? Data, string Message)> LoginAsync(LoginRequestDto dto);
        Task<SpResultDto> UpdateUserAsync(UpdateUserDto dto);
        Task<IEnumerable<UserPermissionDto>> GetUserPermissionsAsync(int userId);
        Task<(bool HasPermission, SpResultDto Result)> ValidateUserPermissionAsync(CheckPermissionDto dto);
    }
}
