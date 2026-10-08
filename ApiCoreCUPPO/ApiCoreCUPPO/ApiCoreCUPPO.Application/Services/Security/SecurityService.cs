using ApiCoreCUPPO.Application.DTOs.Security;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Security;
using ApiCoreCUPPO.Application.Interfaces.IServices.Security;
using System;
using System.Collections.Generic;
using System.Text;

namespace ApiCoreCUPPO.Application.Services.Security
{
    public class SecurityService : ISecurityService
    {
        private readonly ISecurityRepository _securityRepository;
        private readonly IJwtProvider _jwtProvider;

        public SecurityService(ISecurityRepository securityRepository, IJwtProvider jwtProvider)
        {
            _securityRepository = securityRepository;
            _jwtProvider = jwtProvider;
        }

        public async Task<(bool IsSuccess, AuthResponseDto? Data, string Message)> RegisterAsync(RegisterUserDto dto)
        {
            var spResult = await _securityRepository.InsertUserAsync(dto);

            if (!spResult.IsSuccess)
            {
                return (false, null, spResult.MessageResult);
            }

            int createdUserId = spResult.CodeResult;
            var user = await _securityRepository.GetUserByIdAsync(createdUserId);

            if (user == null)
            {
                return (false, null, "Error interno al recuperar los datos del usuario recién registrado.");
            }

            string token = _jwtProvider.GenerateToken(user);
            var permissions = await _securityRepository.GetUserPermissionsAsync(user.UserID);

            var response = new AuthResponseDto
            {
                UserID = user.UserID,
                UserLogin = user.UserLogin,
                Name = user.Name,
                Mail = user.Mail,
                Token = token,
                Permissions = permissions
            };

            return (true, response, spResult.MessageResult);
        }

        public async Task<(bool IsSuccess, AuthResponseDto? Data, string Message)> LoginAsync(LoginRequestDto dto)
        {
            var spResult = await _securityRepository.ValidateUserLoginAsync(dto);

            if (!spResult.IsSuccess)
            {
                return (false, null, spResult.MessageResult);
            }

            int userId = spResult.CodeResult;
            var user = await _securityRepository.GetUserByIdAsync(userId);

            if (user == null)
            {
                return (false, null, "El usuario no existe o se encuentra desactivado.");
            }

            string token = _jwtProvider.GenerateToken(user);
            var permissions = await _securityRepository.GetUserPermissionsAsync(user.UserID);

            var response = new AuthResponseDto
            {
                UserID = user.UserID,
                UserLogin = user.UserLogin,
                Name = user.Name,
                Mail = user.Mail,
                Token = token,
                Permissions = permissions
            };

            return (true, response, spResult.MessageResult);
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