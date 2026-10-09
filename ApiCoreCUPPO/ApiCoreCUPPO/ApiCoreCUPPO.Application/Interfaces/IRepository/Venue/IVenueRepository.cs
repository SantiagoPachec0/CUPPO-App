using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Venue;

namespace ApiCoreCUPPO.Application.Interfaces.IRepository.Venue
{
    public interface IVenueRepository
    {
        // ---------- Complejos
        Task<IEnumerable<OwnerVenueSummaryDto>> GetOwnerVenuesAsync(int userId);
        Task<OwnerVenueDto?> GetVenueForOwnerAsync(int venueId, int userId);
        Task<SpResultDto> InsertVenueAsync(int userId, VenueUpsertDto dto);
        Task<SpResultDto> UpdateVenueAsync(int venueId, int userId, VenueUpsertDto dto);
        Task<SpResultDto> SetVenueStatusAsync(int venueId, int userId, int statusId);
        Task<SpResultDto> SetVenueAmenitiesAsync(int venueId, int userId, IEnumerable<int> amenityIds);

        // ---------- Cuentas de cobro
        Task<SpResultDto> UpsertPaymentAccountAsync(int? accountId, int venueId, int userId, PaymentAccountUpsertDto dto);
        Task<SpResultDto> SetPaymentAccountStatusAsync(int accountId, int userId, int statusId);

        // ---------- Fotos
        Task<SpResultDto> InsertVenuePhotoAsync(int venueId, int userId, string url);
        Task<(SpResultDto Result, string? DeletedUrl)> DeleteVenuePhotoAsync(int photoId, int userId);
        Task<SpResultDto> SetVenueCoverPhotoAsync(int photoId, int userId);

        // ---------- Revisión (SUPERADMIN)
        Task<IEnumerable<VenueRequestDto>> GetVenueRequestsAsync(int? verificationStatusId);
        Task<SpResultDto> ReviewVenueAsync(int venueId, ReviewVerificationDto dto, int reviewerUserId);
    }
}
