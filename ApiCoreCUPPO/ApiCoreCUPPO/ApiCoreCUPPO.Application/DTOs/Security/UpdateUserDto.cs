using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Text;
using System.Text.Json.Serialization;

namespace ApiCoreCUPPO.Application.DTOs.Security
{
    public class UpdateUserDto
    {
        /// <summary>Lo asigna la API a partir del token; no se recibe del cliente.</summary>
        [JsonIgnore]
        public int UserID { get; set; }
        public string? UserLogin { get; set; }
        public string? Name { get; set; }
        public string? Mail { get; set; }
        public bool? Blocked { get; set; }
        public int? FailedLoginAttempts { get; set; }
        public int? StatusID { get; set; }
        [JsonIgnore]
        public int? UpdateUserID { get; set; }
    }
}
