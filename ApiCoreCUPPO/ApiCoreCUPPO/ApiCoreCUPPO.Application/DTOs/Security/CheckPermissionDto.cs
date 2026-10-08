using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Text;
using System.Text.Json.Serialization;

namespace ApiCoreCUPPO.Application.DTOs.Security
{
    public class CheckPermissionDto
    {
        /// <summary>Lo asigna la API a partir del token; no se recibe del cliente.</summary>
        [JsonIgnore]
        public int UserID { get; set; }

        [Required]
        public string ModuleCode { get; set; } = string.Empty;

        [Required]
        public string ActionCode { get; set; } = string.Empty;
    }
}
