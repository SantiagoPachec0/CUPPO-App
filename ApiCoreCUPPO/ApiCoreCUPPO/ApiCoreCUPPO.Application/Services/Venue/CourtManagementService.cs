using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Venue;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Venue;
using ApiCoreCUPPO.Application.Interfaces.IServices.Common;
using ApiCoreCUPPO.Application.Interfaces.IServices.Venue;
using ApiCoreCUPPO.Application.Services.Common;

namespace ApiCoreCUPPO.Application.Services.Venue
{
    public class CourtManagementService : ICourtManagementService
    {
        private const int MaxBlockQueryDays = 62;

        private readonly ICourtRepository _courtRepository;
        private readonly IFileStorage _storage;

        public CourtManagementService(ICourtRepository courtRepository, IFileStorage storage)
        {
            _courtRepository = courtRepository;
            _storage = storage;
        }

        public Task<IEnumerable<OwnerCourtDto>> GetCourtsAsync(int venueId, int userId)
            => _courtRepository.GetCourtsForOwnerAsync(venueId, userId);

        public Task<SpResultDto> CreateCourtAsync(int venueId, int userId, CourtUpsertDto dto)
            => _courtRepository.UpsertCourtAsync(null, venueId, userId, dto);

        public Task<SpResultDto> UpdateCourtAsync(int courtId, int userId, CourtUpsertDto dto)
            => _courtRepository.UpsertCourtAsync(courtId, null, userId, dto);

        public Task<SpResultDto> SetCourtStatusAsync(int courtId, int userId, int statusId)
            => _courtRepository.SetCourtStatusAsync(courtId, userId, statusId);

        public Task<SpResultDto> SetScheduleAsync(int courtId, int userId, IEnumerable<ScheduleItemDto> schedule)
            => _courtRepository.SetCourtScheduleAsync(courtId, userId, schedule);

        public Task<SpResultDto> SetPricesAsync(int courtId, int userId, IEnumerable<PriceItemDto> prices)
            => _courtRepository.SetCourtPricesAsync(courtId, userId, prices);

        public Task<IEnumerable<CourtBlockDto>> GetBlocksAsync(int venueId, int userId, DateTime from, DateTime to)
        {
            // Limita el rango consultado para no traer años de datos
            if (to <= from || (to - from).TotalDays > MaxBlockQueryDays)
                to = from.AddDays(MaxBlockQueryDays);

            return _courtRepository.GetCourtBlocksAsync(venueId, userId, from, to);
        }

        public Task<SpResultDto> CreateBlockAsync(int courtId, int userId, CourtBlockCreateDto dto)
            => _courtRepository.InsertCourtBlockAsync(courtId, userId, dto);

        public Task<SpResultDto> DeleteBlockAsync(int blockId, int userId)
            => _courtRepository.DeleteCourtBlockAsync(blockId, userId);

        public Task<SpResultDto> AddCourtPhotoAsync(int courtId, int userId, UploadFileDto file)
            => PhotoUploader.UploadAsync(_storage, file, "courts", isPrivate: false,
                url => _courtRepository.InsertCourtPhotoAsync(courtId, userId, url));

        public async Task<SpResultDto> DeleteCourtPhotoAsync(int photoId, int userId)
        {
            var (result, deletedUrl) = await _courtRepository.DeleteCourtPhotoAsync(photoId, userId);
            if (result.IsSuccess && deletedUrl is not null)
                await _storage.DeleteAsync(deletedUrl);

            return result;
        }
    }
}
