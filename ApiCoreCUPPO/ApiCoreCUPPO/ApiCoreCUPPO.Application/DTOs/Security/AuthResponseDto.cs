using System;
using System.Collections.Generic;
using System.Text;

namespace ApiCoreCUPPO.Application.DTOs.Security
{
    public class AuthResponseDto
    {
        public int UserID { get; set; }
        public string UserLogin { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string Mail { get; set; } = string.Empty;
        public string Token { get; set; } = string.Empty;
        public IEnumerable<UserPermissionDto> Permissions { get; set; } = new List<UserPermissionDto>();
    }
}
