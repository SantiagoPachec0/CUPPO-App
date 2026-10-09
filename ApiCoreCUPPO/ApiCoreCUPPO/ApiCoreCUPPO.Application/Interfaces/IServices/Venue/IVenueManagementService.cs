using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Venue;

namespace ApiCoreCUPPO.Application.Interfaces.IServices.Venue
{
    /// <summary>Panel de dueño: complejos, comodidades, cuentas de cobro y fotos; revisión por SUPERADMIN.</summary>
    public interface IVenueManagementService
    {
        Task<IEnumerable<OwnerVenueSummaryDto>> GetOwnerVenuesAsync(int userId);
        Task<OwnerVenueDto?> GetVenueForOwnerAsync(int venueId, int userId);
        Task<SpResultDto> CreateVenueAsync(int userId, VenueUpsertDto dto);
        Task<SpResultDto> UpdateVenueAsync(int venueId, int userId, VenueUpsertDto dto);
        Task<SpResultDto> SetVenueStatusAsync(int venueId, int userId, int statusId);
        Task<SpResultDto> SetVenueAmenitiesAsync(int venueId, int userId, IEnumerable<int> amenityIds);

        Task<SpResultDto> UpsertPaymentAccountAsync(int? accountId, int venueId, int userId, PaymentAccountUpsertDto dto);
        Task<SpResultDto> SetPaymentAccountStatusAsync(int accountId, int userId, int statusId);

        Task<SpResultDto> AddVenuePhotoAsync(int venueId, int userId, UploadFileDto file);
        Task<SpResultDto> DeleteVenuePhotoAsync(int photoId, int userId);
        Task<SpResultDto> SetVenueCoverPhotoAsync(int photoId, int userId);

        Task<IEnumerable<VenueRequestDto>> GetVenueRequestsAsync(int? verificationStatusId);
        Task<SpResultDto> ReviewVenueAsync(int venueId, ReviewVerificationDto dto, int reviewerUserId);
    }
}
