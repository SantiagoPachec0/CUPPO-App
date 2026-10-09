using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Venue;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Venue;
using ApiCoreCUPPO.Application.Interfaces.IServices.Common;
using ApiCoreCUPPO.Application.Interfaces.IServices.Venue;
using ApiCoreCUPPO.Application.Services.Common;

namespace ApiCoreCUPPO.Application.Services.Venue
{
    public class VenueManagementService : IVenueManagementService
    {
        private readonly IVenueRepository _venueRepository;
        private readonly IFileStorage _storage;

        public VenueManagementService(IVenueRepository venueRepository, IFileStorage storage)
        {
            _venueRepository = venueRepository;
            _storage = storage;
        }

        public Task<IEnumerable<OwnerVenueSummaryDto>> GetOwnerVenuesAsync(int userId)
            => _venueRepository.GetOwnerVenuesAsync(userId);

        public Task<OwnerVenueDto?> GetVenueForOwnerAsync(int venueId, int userId)
            => _venueRepository.GetVenueForOwnerAsync(venueId, userId);

        public Task<SpResultDto> CreateVenueAsync(int userId, VenueUpsertDto dto)
            => _venueRepository.InsertVenueAsync(userId, dto);

        public Task<SpResultDto> UpdateVenueAsync(int venueId, int userId, VenueUpsertDto dto)
            => _venueRepository.UpdateVenueAsync(venueId, userId, dto);

        public Task<SpResultDto> SetVenueStatusAsync(int venueId, int userId, int statusId)
            => _venueRepository.SetVenueStatusAsync(venueId, userId, statusId);

        public Task<SpResultDto> SetVenueAmenitiesAsync(int venueId, int userId, IEnumerable<int> amenityIds)
            => _venueRepository.SetVenueAmenitiesAsync(venueId, userId, amenityIds);

        public Task<SpResultDto> UpsertPaymentAccountAsync(int? accountId, int venueId, int userId, PaymentAccountUpsertDto dto)
            => _venueRepository.UpsertPaymentAccountAsync(accountId, venueId, userId, dto);

        public Task<SpResultDto> SetPaymentAccountStatusAsync(int accountId, int userId, int statusId)
            => _venueRepository.SetPaymentAccountStatusAsync(accountId, userId, statusId);

        public Task<SpResultDto> AddVenuePhotoAsync(int venueId, int userId, UploadFileDto file)
            => PhotoUploader.UploadAsync(_storage, file, "venues", isPrivate: false,
                url => _venueRepository.InsertVenuePhotoAsync(venueId, userId, url));

        public async Task<SpResultDto> DeleteVenuePhotoAsync(int photoId, int userId)
        {
            var (result, deletedUrl) = await _venueRepository.DeleteVenuePhotoAsync(photoId, userId);
            if (result.IsSuccess && deletedUrl is not null)
                await _storage.DeleteAsync(deletedUrl);

            return result;
        }

        public Task<SpResultDto> SetVenueCoverPhotoAsync(int photoId, int userId)
            => _venueRepository.SetVenueCoverPhotoAsync(photoId, userId);

        public Task<IEnumerable<VenueRequestDto>> GetVenueRequestsAsync(int? verificationStatusId)
            => _venueRepository.GetVenueRequestsAsync(verificationStatusId);

        public Task<SpResultDto> ReviewVenueAsync(int venueId, ReviewVerificationDto dto, int reviewerUserId)
            => _venueRepository.ReviewVenueAsync(venueId, dto, reviewerUserId);
    }
}
