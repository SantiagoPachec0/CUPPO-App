using ApiCoreCUPPO.Application.DTOs.Booking;
using ApiCoreCUPPO.Application.DTOs.Common;

namespace ApiCoreCUPPO.Application.Interfaces.IRepository.Booking
{
    public interface IBookingRepository
    {
        Task<IEnumerable<AvailabilitySlotDto>> GetAvailabilityAsync(int courtId, DateTime date);
        Task<SpResultDto> CreateBookingAsync(int userId, CreateBookingDto dto);
        Task<SpResultDto> CancelBookingAsync(int bookingId, int userId, string? reason);
        Task<IEnumerable<BookingListItemDto>> GetUserBookingsAsync(int userId, bool upcoming, int page, int pageSize);
        Task<BookingDetailDto?> GetBookingDetailAsync(int bookingId, int userId);

        Task<IEnumerable<AgendaItemDto>> GetVenueAgendaAsync(int venueId, int userId, DateTime from, DateTime to);
        Task<SpResultDto> MarkNoShowAsync(int bookingId, int userId);

        // ---------- Procesos automáticos
        Task<SpResultDto> ExpirePendingBookingsAsync();
        Task<SpResultDto> CompletePastBookingsAsync();
    }
}
