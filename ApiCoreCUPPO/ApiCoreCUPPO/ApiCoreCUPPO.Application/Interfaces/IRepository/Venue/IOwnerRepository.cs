using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Venue;

namespace ApiCoreCUPPO.Application.Interfaces.IRepository.Venue
{
    public interface IOwnerRepository
    {
        Task<SpResultDto> RequestVerificationAsync(int userId, OwnerVerificationRequestDto dto, string? documentUrl);
        Task<OwnerProfileDto?> GetOwnerProfileAsync(int userId);
        Task<IEnumerable<OwnerRequestDto>> GetOwnerRequestsAsync(int? verificationStatusId);
        Task<SpResultDto> ReviewVerificationAsync(int userId, ReviewOwnerDto dto, int reviewerUserId);
    }
}
