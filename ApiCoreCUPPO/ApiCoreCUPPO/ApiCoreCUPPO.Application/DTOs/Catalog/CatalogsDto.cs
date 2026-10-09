namespace ApiCoreCUPPO.Application.DTOs.Catalog
{
    public record SportDto(int SportID, string Code, string Name, string? Icon, int DefaultSlotMinutes);
    public record SurfaceDto(int SurfaceID, string Code, string Name);
    public record AmenityDto(int AmenityID, string Code, string Name, string? Icon);
    public record PaymentMethodDto(int PaymentMethodID, string Code, string Name, string Currency, bool RequiresReference, bool IsOnline);
    public record StateDto(int StateID, string Name);
    public record CityDto(int CityID, int StateID, string Name);
    public record ZoneDto(int ZoneID, int CityID, string Name);

    /// <summary>Todos los catálogos en una sola respuesta (GET api/catalog).</summary>
    public class CatalogsDto
    {
        public IEnumerable<SportDto> Sports { get; set; } = [];
        public IEnumerable<SurfaceDto> Surfaces { get; set; } = [];
        public IEnumerable<AmenityDto> Amenities { get; set; } = [];
        public IEnumerable<PaymentMethodDto> PaymentMethods { get; set; } = [];
        public IEnumerable<StateDto> States { get; set; } = [];
        public IEnumerable<CityDto> Cities { get; set; } = [];
        public IEnumerable<ZoneDto> Zones { get; set; } = [];
    }
}
