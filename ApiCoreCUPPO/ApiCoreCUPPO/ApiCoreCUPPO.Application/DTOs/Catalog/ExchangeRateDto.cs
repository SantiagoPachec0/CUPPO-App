using System.ComponentModel.DataAnnotations;

namespace ApiCoreCUPPO.Application.DTOs.Catalog
{
    public class ExchangeRateDto
    {
        public DateTime RateDate { get; set; }
        public string Currency { get; set; } = "VES";
        public decimal RatePerUSD { get; set; }
        public string Source { get; set; } = "BCV";
    }

    public class UpsertExchangeRateDto
    {
        [Required]
        public DateTime RateDate { get; set; }

        [Range(0.0001, 100000000, ErrorMessage = "La tasa debe ser mayor que cero.")]
        public decimal RatePerUSD { get; set; }

        [StringLength(20)]
        public string Source { get; set; } = "BCV";
    }
}
