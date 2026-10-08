using System;
using System.Collections.Generic;
using System.Text;

namespace ApiCoreCUPPO.Application.DTOs.Security
{
    public class SpResultDto
    {
        public int CodeResult { get; set; }
        public string MessageResult { get; set; } = string.Empty;
        public bool IsSuccess => CodeResult > 0;
    }
}
