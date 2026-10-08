using System;
using System.Collections.Generic;
using System.Text;

namespace ApiCoreCUPPO.Domain.Entities
{
    public class Role
    {
        public int RoleID { get; set; }
        public string Code { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }
        public int StatusID { get; set; }
    }
}
