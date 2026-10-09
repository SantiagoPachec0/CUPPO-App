using ApiCoreCUPPO.Application.DTOs.Catalog;
using ApiCoreCUPPO.Application.DTOs.Venue;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Venue;
using ApiCoreCUPPO.Infrastructure.Data;
using Dapper;
using System.Data;

namespace ApiCoreCUPPO.Infrastructure.Repositories.Venue
{
    public class PublicVenueRepository : IPublicVenueRepository
    {
        private readonly IDbConnectionFactory _db;

        public PublicVenueRepository(IDbConnectionFactory db)
        {
            _db = db;
        }

        public async Task<IEnumerable<VenueSearchItemDto>> SearchAsync(VenueSearchQueryDto query)
        {
            using var connection = _db.CreateConnection();
            return await connection.QueryAsync<VenueSearchItemDto>("[Venue].[SearchVenues]", new
            {
                query.SportID,
                query.CityID,
                query.ZoneID,
                query.Search,
                query.Latitude,
                query.Longitude,
                query.Page,
                query.PageSize
            }, commandType: CommandType.StoredProcedure);
        }

        public async Task<PublicVenueDto?> GetPublicVenueAsync(int venueId)
        {
            using var connection = _db.CreateConnection();
            using var grid = await connection.QueryMultipleAsync(
                "[Venue].[GetPublicVenue]", new { VenueID = venueId }, commandType: CommandType.StoredProcedure);

            var venue = await grid.ReadFirstOrDefaultAsync<PublicVenueDto>();
            var photos = (await grid.ReadAsync<VenuePhotoDto>()).ToList();
            var amenities = (await grid.ReadAsync<AmenityDto>()).ToList();
            var courts = (await grid.ReadAsync<PublicCourtDto>()).ToList();
            var courtPhotos = (await grid.ReadAsync<CourtPhotoDto>()).ToLookup(p => p.CourtID);
            var paymentMethods = (await grid.ReadAsync<AcceptedPaymentMethodDto>()).ToList();

            if (venue is null)
                return null;

            foreach (var court in courts)
                court.Photos = courtPhotos[court.CourtID].ToList();

            venue.Photos = photos;
            venue.Amenities = amenities;
            venue.Courts = courts;
            venue.PaymentMethods = paymentMethods;
            return venue;
        }
    }
}
