using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Venue;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Venue;
using ApiCoreCUPPO.Application.Interfaces.IServices.Venue;

namespace ApiCoreCUPPO.Application.Services.Venue
{
    public class PublicVenueService : IPublicVenueService
    {
        private readonly IPublicVenueRepository _repository;

        public PublicVenueService(IPublicVenueRepository repository)
        {
            _repository = repository;
        }

        public async Task<PagedResultDto<VenueSearchItemDto>> SearchAsync(VenueSearchQueryDto query)
        {
            // La distancia solo tiene sentido con ambas coordenadas
            if (query.Latitude is null || query.Longitude is null)
            {
                query.Latitude = null;
                query.Longitude = null;
            }

            var items = (await _repository.SearchAsync(query)).ToList();

            return new PagedResultDto<VenueSearchItemDto>
            {
                Items = items,
                Page = query.Page,
                PageSize = query.PageSize,
                TotalCount = items.FirstOrDefault()?.TotalCount ?? 0
            };
        }

        public Task<PublicVenueDto?> GetVenueAsync(int venueId)
            => _repository.GetPublicVenueAsync(venueId);
    }
}
