using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Venue;

namespace ApiCoreCUPPO.Application.Interfaces.IRepository.Venue
{
    public interface ICourtRepository
    {
        Task<IEnumerable<OwnerCourtDto>> GetCourtsForOwnerAsync(int venueId, int userId);

        /// <summary>courtId null = crear en venueId; si no, editar la cancha.</summary>
        Task<SpResultDto> UpsertCourtAsync(int? courtId, int? venueId, int userId, CourtUpsertDto dto);
        Task<SpResultDto> SetCourtStatusAsync(int courtId, int userId, int statusId);
        Task<SpResultDto> SetCourtScheduleAsync(int courtId, int userId, IEnumerable<ScheduleItemDto> schedule);
        Task<SpResultDto> SetCourtPricesAsync(int courtId, int userId, IEnumerable<PriceItemDto> prices);

        Task<IEnumerable<CourtBlockDto>> GetCourtBlocksAsync(int venueId, int userId, DateTime from, DateTime to);
        Task<SpResultDto> InsertCourtBlockAsync(int courtId, int userId, CourtBlockCreateDto dto);
        Task<SpResultDto> DeleteCourtBlockAsync(int blockId, int userId);

        Task<SpResultDto> InsertCourtPhotoAsync(int courtId, int userId, string url);
        Task<(SpResultDto Result, string? DeletedUrl)> DeleteCourtPhotoAsync(int photoId, int userId);
    }
}
