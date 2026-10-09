using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Venue;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Venue;
using ApiCoreCUPPO.Application.Interfaces.IServices.Common;
using ApiCoreCUPPO.Application.Interfaces.IServices.Venue;
using ApiCoreCUPPO.Application.Services.Common;

namespace ApiCoreCUPPO.Application.Services.Venue
{
    public class OwnerService : IOwnerService
    {
        private readonly IOwnerRepository _ownerRepository;
        private readonly IFileStorage _storage;

        public OwnerService(IOwnerRepository ownerRepository, IFileStorage storage)
        {
            _ownerRepository = ownerRepository;
            _storage = storage;
        }

        public Task<SpResultDto> RequestVerificationAsync(int userId, OwnerVerificationRequestDto dto)
            => _ownerRepository.RequestVerificationAsync(userId, dto, documentUrl: null);

        public Task<OwnerProfileDto?> GetOwnerProfileAsync(int userId)
            => _ownerRepository.GetOwnerProfileAsync(userId);

        public Task<IEnumerable<OwnerRequestDto>> GetOwnerRequestsAsync(int? verificationStatusId)
            => _ownerRepository.GetOwnerRequestsAsync(verificationStatusId);

        public Task<SpResultDto> ReviewVerificationAsync(int userId, ReviewVerificationDto dto, int reviewerUserId)
            => _ownerRepository.ReviewVerificationAsync(userId, dto, reviewerUserId);

        public async Task<SpResultDto> UploadDocumentAsync(int userId, UploadFileDto file)
        {
            string? previousUrl = null;
            var result = await PhotoUploader.UploadAsync(_storage, file, "owner-documents", isPrivate: true, async url =>
            {
                var (spResult, previous) = await _ownerRepository.SetOwnerDocumentAsync(userId, url);
                previousUrl = previous;
                return spResult;
            });

            if (result.IsSuccess && previousUrl is not null)
                await _storage.DeleteAsync(previousUrl);

            return result;
        }

        public async Task<(Stream Content, string ContentType)?> OpenDocumentAsync(int userId)
        {
            var profile = await _ownerRepository.GetOwnerProfileAsync(userId);
            if (profile?.DocumentUrl is null)
                return null;

            var stream = _storage.OpenPrivate(profile.DocumentUrl);
            if (stream is null)
                return null;

            var contentType = Path.GetExtension(profile.DocumentUrl).ToLowerInvariant() switch
            {
                ".png" => "image/png",
                ".webp" => "image/webp",
                _ => "image/jpeg"
            };
            return (stream, contentType);
        }
    }
}
