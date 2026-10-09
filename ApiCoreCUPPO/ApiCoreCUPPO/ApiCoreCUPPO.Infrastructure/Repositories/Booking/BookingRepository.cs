using ApiCoreCUPPO.Application.DTOs.Booking;
using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Booking;
using ApiCoreCUPPO.Infrastructure.Data;
using Dapper;
using System.Data;

namespace ApiCoreCUPPO.Infrastructure.Repositories.Booking
{
    public class BookingRepository : IBookingRepository
    {
        private readonly IDbConnectionFactory _db;

        public BookingRepository(IDbConnectionFactory db)
        {
            _db = db;
        }

        public async Task<IEnumerable<AvailabilitySlotDto>> GetAvailabilityAsync(int courtId, DateTime date)
        {
            using var connection = _db.CreateConnection();
            return await connection.QueryAsync<AvailabilitySlotDto>(
                "[Booking].[GetCourtAvailability]",
                new { CourtID = courtId, Date = new DbString { Value = date.ToString("yyyy-MM-dd"), IsAnsi = true } },
                commandType: CommandType.StoredProcedure);
        }

        public async Task<SpResultDto> CreateBookingAsync(int userId, CreateBookingDto dto)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Booking].[CreateBooking]", new
            {
                dto.CourtID,
                UserID = userId,
                dto.StartDateTime,
                dto.DurationMinutes,
                dto.Notes
            });
        }

        public async Task<SpResultDto> CancelBookingAsync(int bookingId, int userId, string? reason)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Booking].[CancelBooking]", new { BookingID = bookingId, UserID = userId, Reason = reason });
        }

        public async Task<IEnumerable<BookingListItemDto>> GetUserBookingsAsync(int userId, bool upcoming, int page, int pageSize)
        {
            using var connection = _db.CreateConnection();
            return await connection.QueryAsync<BookingListItemDto>("[Booking].[GetUserBookings]", new
            {
                UserID = userId,
                Scope = upcoming ? "UPCOMING" : "PAST",
                Page = page,
                PageSize = pageSize
            }, commandType: CommandType.StoredProcedure);
        }

        public async Task<BookingDetailDto?> GetBookingDetailAsync(int bookingId, int userId)
        {
            using var connection = _db.CreateConnection();
            using var grid = await connection.QueryMultipleAsync(
                "[Booking].[GetBookingDetail]", new { BookingID = bookingId, UserID = userId }, commandType: CommandType.StoredProcedure);

            var booking = await grid.ReadFirstOrDefaultAsync<BookingDetailDto>();
            var accounts = (await grid.ReadAsync<PaymentInstructionDto>()).ToList();
            var payments = (await grid.ReadAsync<PaymentSummaryDto>()).ToList();

            if (booking is null)
                return null;

            booking.PaymentAccounts = accounts;
            booking.Payments = payments;
            return booking;
        }

        public async Task<IEnumerable<AgendaItemDto>> GetVenueAgendaAsync(int venueId, int userId, DateTime from, DateTime to)
        {
            using var connection = _db.CreateConnection();
            return await connection.QueryAsync<AgendaItemDto>(
                "[Booking].[GetVenueAgenda]", new { VenueID = venueId, UserID = userId, From = from, To = to }, commandType: CommandType.StoredProcedure);
        }

        public async Task<SpResultDto> MarkNoShowAsync(int bookingId, int userId)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Booking].[MarkNoShow]", new { BookingID = bookingId, UserID = userId });
        }

        public async Task<SpResultDto> ExpirePendingBookingsAsync()
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Booking].[ExpirePendingBookings]", new DynamicParameters());
        }

        public async Task<SpResultDto> CompletePastBookingsAsync()
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Booking].[CompletePastBookings]", new DynamicParameters());
        }
    }
}
