using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Venue;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Venue;
using ApiCoreCUPPO.Application.Interfaces.IServices.Venue;

namespace ApiCoreCUPPO.Application.Services.Venue
{
    public class OwnerService : IOwnerService
    {
        private readonly IOwnerRepository _ownerRepository;

        public OwnerService(IOwnerRepository ownerRepository)
        {
            _ownerRepository = ownerRepository;
        }

        public Task<SpResultDto> RequestVerificationAsync(int userId, OwnerVerificationRequestDto dto)
            => _ownerRepository.RequestVerificationAsync(userId, dto, documentUrl: null);

        public Task<OwnerProfileDto?> GetOwnerProfileAsync(int userId)
            => _ownerRepository.GetOwnerProfileAsync(userId);

        public Task<IEnumerable<OwnerRequestDto>> GetOwnerRequestsAsync(int? verificationStatusId)
            => _ownerRepository.GetOwnerRequestsAsync(verificationStatusId);

        public Task<SpResultDto> ReviewVerificationAsync(int userId, ReviewOwnerDto dto, int reviewerUserId)
            => _ownerRepository.ReviewVerificationAsync(userId, dto, reviewerUserId);
    }
}
