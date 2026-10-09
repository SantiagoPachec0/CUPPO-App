using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Security;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Security;
using ApiCoreCUPPO.Application.Interfaces.IServices.Security;

namespace ApiCoreCUPPO.Application.Services.Security
{
    public class SecurityService : ISecurityService
    {
        private readonly ISecurityRepository _securityRepository;

        public SecurityService(ISecurityRepository securityRepository)
        {
            _securityRepository = securityRepository;
        }

        public async Task<SpResultDto> UpdateUserAsync(UpdateUserDto dto)
        {
            return await _securityRepository.UpdateUserAsync(dto);
        }

        public async Task<IEnumerable<UserPermissionDto>> GetUserPermissionsAsync(int userId)
        {
            return await _securityRepository.GetUserPermissionsAsync(userId);
        }

        public async Task<(bool HasPermission, SpResultDto Result)> ValidateUserPermissionAsync(CheckPermissionDto dto)
        {
            return await _securityRepository.ValidateUserPermissionAsync(dto);
        }
    }
}
