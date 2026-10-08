using System;
using System.Collections.Generic;
using System.Text;

namespace ApiCoreCUPPO.Domain.Entities
{
    public class Module
    {
        public int ModuleID { get; set; }
        public string Code { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }
        public int? ParentModuleID { get; set; }
        public string? Icon { get; set; }
        public string? Route { get; set; }
        public int DisplayOrder { get; set; }
        public int StatusID { get; set; }
    }
}
