using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Venue;

namespace ApiCoreCUPPO.Application.Interfaces.IServices.Venue
{
    public interface IOwnerService
    {
        Task<SpResultDto> RequestVerificationAsync(int userId, OwnerVerificationRequestDto dto);
        Task<OwnerProfileDto?> GetOwnerProfileAsync(int userId);
        Task<IEnumerable<OwnerRequestDto>> GetOwnerRequestsAsync(int? verificationStatusId);
        Task<SpResultDto> ReviewVerificationAsync(int userId, ReviewVerificationDto dto, int reviewerUserId);

        /// <summary>Sube la foto de cédula/RIF (archivo privado). Reemplaza la anterior.</summary>
        Task<SpResultDto> UploadDocumentAsync(int userId, UploadFileDto file);

        /// <summary>Abre el documento de un dueño (solo para SUPERADMIN). null si no tiene.</summary>
        Task<(Stream Content, string ContentType)?> OpenDocumentAsync(int userId);
    }
}
