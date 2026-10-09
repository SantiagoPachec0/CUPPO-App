using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Security;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Security;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Venue;
using ApiCoreCUPPO.Application.Interfaces.IServices.Security;

namespace ApiCoreCUPPO.Application.Services.Security
{
    public class SecurityService : ISecurityService
    {
        private readonly ISecurityRepository _securityRepository;
        private readonly IOwnerRepository _ownerRepository;

        public SecurityService(ISecurityRepository securityRepository, IOwnerRepository ownerRepository)
        {
            _securityRepository = securityRepository;
            _ownerRepository = ownerRepository;
        }

        public async Task<UserProfileDto?> GetProfileAsync(int userId)
        {
            var user = await _securityRepository.GetUserByIdAsync(userId);
            if (user is null)
                return null;

            return new UserProfileDto
            {
                UserID = user.UserID,
                UserLogin = user.UserLogin,
                Name = user.Name,
                Mail = user.Mail,
                Roles = await _securityRepository.GetUserRolesAsync(userId),
                OwnerProfile = await _ownerRepository.GetOwnerProfileAsync(userId)
            };
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
