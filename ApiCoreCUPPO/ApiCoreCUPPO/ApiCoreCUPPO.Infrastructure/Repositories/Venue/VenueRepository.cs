using ApiCoreCUPPO.Application.DTOs.Catalog;
using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Venue;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Venue;
using ApiCoreCUPPO.Infrastructure.Data;
using Dapper;
using System.Data;

namespace ApiCoreCUPPO.Infrastructure.Repositories.Venue
{
    public class VenueRepository : IVenueRepository
    {
        private readonly IDbConnectionFactory _db;

        public VenueRepository(IDbConnectionFactory db)
        {
            _db = db;
        }

        // ---------- Complejos

        public async Task<IEnumerable<OwnerVenueSummaryDto>> GetOwnerVenuesAsync(int userId)
        {
            using var connection = _db.CreateConnection();
            return await connection.QueryAsync<OwnerVenueSummaryDto>(
                "[Venue].[GetOwnerVenues]", new { UserID = userId }, commandType: CommandType.StoredProcedure);
        }

        public async Task<OwnerVenueDto?> GetVenueForOwnerAsync(int venueId, int userId)
        {
            using var connection = _db.CreateConnection();
            using var grid = await connection.QueryMultipleAsync(
                "[Venue].[GetVenueForOwner]", new { VenueID = venueId, UserID = userId }, commandType: CommandType.StoredProcedure);

            var venue = await grid.ReadFirstOrDefaultAsync<OwnerVenueDto>();
            var photos = (await grid.ReadAsync<VenuePhotoDto>()).ToList();
            var amenities = (await grid.ReadAsync<AmenityDto>()).ToList();
            var accounts = (await grid.ReadAsync<PaymentAccountDto>()).ToList();

            if (venue is null)
                return null;

            venue.Photos = photos;
            venue.Amenities = amenities;
            venue.PaymentAccounts = accounts;
            return venue;
        }

        public async Task<SpResultDto> InsertVenueAsync(int userId, VenueUpsertDto dto)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Venue].[InsertVenue]", VenueParameters(userId, dto));
        }

        public async Task<SpResultDto> UpdateVenueAsync(int venueId, int userId, VenueUpsertDto dto)
        {
            using var connection = _db.CreateConnection();
            var parameters = VenueParameters(userId, dto);
            parameters.Add("@VenueID", venueId);
            return await connection.ExecuteSpAsync("[Venue].[UpdateVenue]", parameters);
        }

        public async Task<SpResultDto> SetVenueStatusAsync(int venueId, int userId, int statusId)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Venue].[SetVenueStatus]", new { VenueID = venueId, UserID = userId, StatusID = statusId });
        }

        public async Task<SpResultDto> SetVenueAmenitiesAsync(int venueId, int userId, IEnumerable<int> amenityIds)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Venue].[SetVenueAmenities]", new
            {
                VenueID = venueId,
                UserID = userId,
                AmenityIDs = string.Join(',', amenityIds.Distinct())
            });
        }

        // ---------- Cuentas de cobro

        public async Task<SpResultDto> UpsertPaymentAccountAsync(int? accountId, int venueId, int userId, PaymentAccountUpsertDto dto)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Venue].[UpsertVenuePaymentAccount]", new
            {
                VenuePaymentAccountID = accountId,
                VenueID = venueId,
                UserID = userId,
                dto.PaymentMethodID,
                dto.BankName,
                dto.AccountHolder,
                dto.DocumentNumber,
                dto.Phone,
                dto.AccountNumber,
                dto.Email,
                dto.Notes
            });
        }

        public async Task<SpResultDto> SetPaymentAccountStatusAsync(int accountId, int userId, int statusId)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Venue].[SetVenuePaymentAccountStatus]",
                new { VenuePaymentAccountID = accountId, UserID = userId, StatusID = statusId });
        }

        // ---------- Fotos

        public async Task<SpResultDto> InsertVenuePhotoAsync(int venueId, int userId, string url)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Venue].[InsertVenuePhoto]", new { VenueID = venueId, UserID = userId, Url = url });
        }

        public async Task<(SpResultDto Result, string? DeletedUrl)> DeleteVenuePhotoAsync(int photoId, int userId)
        {
            using var connection = _db.CreateConnection();
            var parameters = new DynamicParameters(new { VenuePhotoID = photoId, UserID = userId });
            parameters.Add("@DeletedUrl", dbType: DbType.String, size: 500, direction: ParameterDirection.Output);

            var result = await connection.ExecuteSpAsync("[Venue].[DeleteVenuePhoto]", parameters);
            return (result, parameters.Get<string?>("@DeletedUrl"));
        }

        public async Task<SpResultDto> SetVenueCoverPhotoAsync(int photoId, int userId)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Venue].[SetVenueCoverPhoto]", new { VenuePhotoID = photoId, UserID = userId });
        }

        // ---------- Revisión (SUPERADMIN)

        public async Task<IEnumerable<VenueRequestDto>> GetVenueRequestsAsync(int? verificationStatusId)
        {
            using var connection = _db.CreateConnection();
            return await connection.QueryAsync<VenueRequestDto>(
                "[Venue].[GetVenueRequests]", new { VerificationStatusID = verificationStatusId }, commandType: CommandType.StoredProcedure);
        }

        public async Task<SpResultDto> ReviewVenueAsync(int venueId, ReviewVerificationDto dto, int reviewerUserId)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Venue].[ReviewVenue]", new
            {
                VenueID = venueId,
                dto.VerificationStatusID,
                dto.ReviewNotes,
                ReviewerUserID = reviewerUserId
            });
        }

        private static DynamicParameters VenueParameters(int userId, VenueUpsertDto dto) => new(new
        {
            UserID = userId,
            dto.Name,
            dto.Description,
            dto.ZoneID,
            dto.Address,
            dto.Latitude,
            dto.Longitude,
            dto.Phone,
            dto.WhatsApp,
            dto.Instagram,
            dto.BookingHoldMinutes,
            dto.CancellationHours
        });
    }
}
