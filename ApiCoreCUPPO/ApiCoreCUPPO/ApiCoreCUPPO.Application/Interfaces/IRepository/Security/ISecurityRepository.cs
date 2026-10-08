using ApiCoreCUPPO.Application.DTOs.Security;
using ApiCoreCUPPO.Domain.Entities;
using System;
using System.Collections.Generic;
using System.Text;

namespace ApiCoreCUPPO.Application.Interfaces.IRepository.Security
{
    public interface ISecurityRepository
    {
        /// <summary>
        /// Registra un nuevo usuario en el sistema ejecutando el Stored Procedure correspondiente.
        /// </summary>
        Task<SpResultDto> InsertUserAsync(RegisterUserDto dto);

        /// <summary>
        /// Valida las credenciales de acceso de un usuario.
        /// </summary>
        Task<SpResultDto> ValidateUserLoginAsync(LoginRequestDto dto);

        /// <summary>
        /// Obtiene la entidad del usuario por su identificador único.
        /// </summary>
        Task<User?> GetUserByIdAsync(int userId);

        /// <summary>
        /// Obtiene la lista de permisos asignados a un usuario.
        /// </summary>
        Task<IEnumerable<UserPermissionDto>> GetUserPermissionsAsync(int userId);

        /// <summary>
        /// Actualiza la información de un usuario existente.
        /// </summary>
        Task<SpResultDto> UpdateUserAsync(UpdateUserDto dto);

        /// <summary>
        /// Valida si un usuario posee permisos sobre una acción o endpoint específico.
        /// </summary>
        Task<(bool HasPermission, SpResultDto Result)> ValidateUserPermissionAsync(CheckPermissionDto dto);
    }
}
