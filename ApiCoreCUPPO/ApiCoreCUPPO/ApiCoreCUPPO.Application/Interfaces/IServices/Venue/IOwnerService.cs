using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Venue;

namespace ApiCoreCUPPO.Application.Interfaces.IServices.Venue
{
    public interface IOwnerService
    {
        Task<SpResultDto> RequestVerificationAsync(int userId, OwnerVerificationRequestDto dto);
        Task<OwnerProfileDto?> GetOwnerProfileAsync(int userId);
        Task<IEnumerable<OwnerRequestDto>> GetOwnerRequestsAsync(int? verificationStatusId);
        Task<SpResultDto> ReviewVerificationAsync(int userId, ReviewOwnerDto dto, int reviewerUserId);
    }
}
