using System;
using System.Collections.Generic;
using System.Text;

namespace ApiCoreCUPPO.Application.DTOs.Security
{
    public class UserPermissionDto
    {
        public int ModuleID { get; set; }
        public string ModuleCode { get; set; } = string.Empty;
        public string ModuleName { get; set; } = string.Empty;
        public int? ParentModuleID { get; set; }
        public string? Icon { get; set; }
        public string? Route { get; set; }
        public int DisplayOrder { get; set; }
        public int ActionID { get; set; }
        public string ActionCode { get; set; } = string.Empty;
        public string ActionName { get; set; } = string.Empty;
    }
}
