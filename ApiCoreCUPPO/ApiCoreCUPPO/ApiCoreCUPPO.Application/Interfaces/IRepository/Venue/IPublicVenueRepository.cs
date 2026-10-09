using ApiCoreCUPPO.Application.DTOs.Venue;

namespace ApiCoreCUPPO.Application.Interfaces.IRepository.Venue
{
    public interface IPublicVenueRepository
    {
        Task<IEnumerable<VenueSearchItemDto>> SearchAsync(VenueSearchQueryDto query);
        Task<PublicVenueDto?> GetPublicVenueAsync(int venueId);
    }
}
