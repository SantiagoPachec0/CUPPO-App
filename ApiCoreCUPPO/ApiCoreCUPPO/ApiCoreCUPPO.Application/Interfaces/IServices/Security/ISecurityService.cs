using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Security;

namespace ApiCoreCUPPO.Application.Interfaces.IServices.Security
{
    public interface ISecurityService
    {
        Task<UserProfileDto?> GetProfileAsync(int userId);
        Task<SpResultDto> UpdateUserAsync(UpdateUserDto dto);
        Task<IEnumerable<UserPermissionDto>> GetUserPermissionsAsync(int userId);
        Task<(bool HasPermission, SpResultDto Result)> ValidateUserPermissionAsync(CheckPermissionDto dto);
    }
}
