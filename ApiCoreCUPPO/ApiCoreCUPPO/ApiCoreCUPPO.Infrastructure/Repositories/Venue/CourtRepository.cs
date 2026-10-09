using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Venue;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Venue;
using ApiCoreCUPPO.Infrastructure.Data;
using Dapper;
using System.Data;
using System.Text.Json;

namespace ApiCoreCUPPO.Infrastructure.Repositories.Venue
{
    public class CourtRepository : ICourtRepository
    {
        // Los SP leen el JSON en camelCase ($.dayOfWeek, $.openTime...)
        private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

        private readonly IDbConnectionFactory _db;

        public CourtRepository(IDbConnectionFactory db)
        {
            _db = db;
        }

        private record ScheduleRow(int CourtID, int DayOfWeek, string OpenTime, string CloseTime);
        private record PriceRow(int CourtID, int? DayOfWeek, string StartTime, string EndTime, decimal PricePerHourUSD);

        public async Task<IEnumerable<OwnerCourtDto>> GetCourtsForOwnerAsync(int venueId, int userId)
        {
            using var connection = _db.CreateConnection();
            using var grid = await connection.QueryMultipleAsync(
                "[Venue].[GetCourtsForOwner]", new { VenueID = venueId, UserID = userId }, commandType: CommandType.StoredProcedure);

            var courts = (await grid.ReadAsync<OwnerCourtDto>()).ToList();
            var schedules = (await grid.ReadAsync<ScheduleRow>()).ToLookup(s => s.CourtID);
            var prices = (await grid.ReadAsync<PriceRow>()).ToLookup(p => p.CourtID);
            var photos = (await grid.ReadAsync<CourtPhotoDto>()).ToLookup(p => p.CourtID);

            foreach (var court in courts)
            {
                court.Schedule = schedules[court.CourtID]
                    .Select(s => new ScheduleItemDto { DayOfWeek = s.DayOfWeek, OpenTime = s.OpenTime, CloseTime = s.CloseTime })
                    .ToList();
                court.Prices = prices[court.CourtID]
                    .Select(p => new PriceItemDto { DayOfWeek = p.DayOfWeek, StartTime = p.StartTime, EndTime = p.EndTime, PricePerHourUSD = p.PricePerHourUSD })
                    .ToList();
                court.Photos = photos[court.CourtID].ToList();
            }

            return courts;
        }

        public async Task<SpResultDto> UpsertCourtAsync(int? courtId, int? venueId, int userId, CourtUpsertDto dto)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Venue].[UpsertCourt]", new
            {
                CourtID = courtId,
                VenueID = venueId,
                UserID = userId,
                dto.SportID,
                dto.SurfaceID,
                dto.Name,
                dto.Description,
                dto.IsCovered,
                dto.HasLighting,
                dto.PlayersCapacity,
                dto.SlotMinutes
            });
        }

        public async Task<SpResultDto> SetCourtStatusAsync(int courtId, int userId, int statusId)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Venue].[SetCourtStatus]", new { CourtID = courtId, UserID = userId, StatusID = statusId });
        }

        public async Task<SpResultDto> SetCourtScheduleAsync(int courtId, int userId, IEnumerable<ScheduleItemDto> schedule)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Venue].[SetCourtSchedule]", new
            {
                CourtID = courtId,
                UserID = userId,
                ScheduleJson = JsonSerializer.Serialize(schedule, JsonOptions)
            });
        }

        public async Task<SpResultDto> SetCourtPricesAsync(int courtId, int userId, IEnumerable<PriceItemDto> prices)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Venue].[SetCourtPrices]", new
            {
                CourtID = courtId,
                UserID = userId,
                PricesJson = JsonSerializer.Serialize(prices, JsonOptions)
            });
        }

        public async Task<IEnumerable<CourtBlockDto>> GetCourtBlocksAsync(int venueId, int userId, DateTime from, DateTime to)
        {
            using var connection = _db.CreateConnection();
            return await connection.QueryAsync<CourtBlockDto>(
                "[Venue].[GetCourtBlocks]", new { VenueID = venueId, UserID = userId, From = from, To = to }, commandType: CommandType.StoredProcedure);
        }

        public async Task<SpResultDto> InsertCourtBlockAsync(int courtId, int userId, CourtBlockCreateDto dto)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Venue].[InsertCourtBlock]", new
            {
                CourtID = courtId,
                UserID = userId,
                dto.StartDateTime,
                dto.EndDateTime,
                dto.Reason
            });
        }

        public async Task<SpResultDto> DeleteCourtBlockAsync(int blockId, int userId)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Venue].[DeleteCourtBlock]", new { CourtBlockID = blockId, UserID = userId });
        }

        public async Task<SpResultDto> InsertCourtPhotoAsync(int courtId, int userId, string url)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Venue].[InsertCourtPhoto]", new { CourtID = courtId, UserID = userId, Url = url });
        }

        public async Task<(SpResultDto Result, string? DeletedUrl)> DeleteCourtPhotoAsync(int photoId, int userId)
        {
            using var connection = _db.CreateConnection();
            var parameters = new DynamicParameters(new { CourtPhotoID = photoId, UserID = userId });
            parameters.Add("@DeletedUrl", dbType: DbType.String, size: 500, direction: ParameterDirection.Output);

            var result = await connection.ExecuteSpAsync("[Venue].[DeleteCourtPhoto]", parameters);
            return (result, parameters.Get<string?>("@DeletedUrl"));
        }
    }
}
