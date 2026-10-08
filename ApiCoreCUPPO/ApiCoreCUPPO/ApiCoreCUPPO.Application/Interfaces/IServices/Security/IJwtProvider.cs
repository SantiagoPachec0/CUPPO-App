using ApiCoreCUPPO.Domain.Entities;
using System;
using System.Collections.Generic;
using System.Text;

namespace ApiCoreCUPPO.Application.Interfaces.IServices.Security
{
    public interface IJwtProvider
    {
        string GenerateToken(User user);
    }
}
