using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Venue;

namespace ApiCoreCUPPO.Application.Interfaces.IServices.Venue
{
    /// <summary>Búsqueda y ficha de complejos para los jugadores.</summary>
    public interface IPublicVenueService
    {
        Task<PagedResultDto<VenueSearchItemDto>> SearchAsync(VenueSearchQueryDto query);
        Task<PublicVenueDto?> GetVenueAsync(int venueId);
    }
}
