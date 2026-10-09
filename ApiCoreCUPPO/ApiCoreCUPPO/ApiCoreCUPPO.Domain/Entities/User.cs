using System;
using System.Collections.Generic;
using System.Text;

namespace ApiCoreCUPPO.Domain.Entities
{
    public class User
    {
        public int UserID { get; set; }
        public string UserLogin { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string Mail { get; set; } = string.Empty;
        /// <summary>Hash anterior (SHA-512 en SQL). NULL cuando el usuario ya migró a BCrypt.</summary>
        public byte[]? PasswordHash { get; set; }
        public byte[]? PasswordSalt { get; set; }
        public string? PasswordBcrypt { get; set; }
        public bool Blocked { get; set; }
        public int FailedLoginAttempts { get; set; }
        public int StatusID { get; set; }
        public int? CreationUserID { get; set; }
        public int? UpdateUserID { get; set; }
        public DateTime CreationDate { get; set; }
        public DateTime? UpdateDate { get; set; }
    }
}
