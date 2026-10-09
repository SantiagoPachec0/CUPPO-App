using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Venue;

namespace ApiCoreCUPPO.Application.Interfaces.IServices.Venue
{
    /// <summary>Panel de dueño: canchas, horarios, precios, bloqueos y fotos de canchas.</summary>
    public interface ICourtManagementService
    {
        Task<IEnumerable<OwnerCourtDto>> GetCourtsAsync(int venueId, int userId);
        Task<SpResultDto> CreateCourtAsync(int venueId, int userId, CourtUpsertDto dto);
        Task<SpResultDto> UpdateCourtAsync(int courtId, int userId, CourtUpsertDto dto);
        Task<SpResultDto> SetCourtStatusAsync(int courtId, int userId, int statusId);
        Task<SpResultDto> SetScheduleAsync(int courtId, int userId, IEnumerable<ScheduleItemDto> schedule);
        Task<SpResultDto> SetPricesAsync(int courtId, int userId, IEnumerable<PriceItemDto> prices);

        Task<IEnumerable<CourtBlockDto>> GetBlocksAsync(int venueId, int userId, DateTime from, DateTime to);
        Task<SpResultDto> CreateBlockAsync(int courtId, int userId, CourtBlockCreateDto dto);
        Task<SpResultDto> DeleteBlockAsync(int blockId, int userId);

        Task<SpResultDto> AddCourtPhotoAsync(int courtId, int userId, UploadFileDto file);
        Task<SpResultDto> DeleteCourtPhotoAsync(int photoId, int userId);
    }
}
