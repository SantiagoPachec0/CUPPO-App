using ApiCoreCUPPO.Application.DTOs.Booking;
using ApiCoreCUPPO.Application.DTOs.Common;

namespace ApiCoreCUPPO.Application.Interfaces.IServices.Booking
{
    public interface IBookingService
    {
        Task<IEnumerable<AvailabilitySlotDto>> GetAvailabilityAsync(int courtId, DateTime date);

        /// <summary>Crea la reserva y devuelve su detalle (con los datos para pagar).</summary>
        Task<(SpResultDto Result, BookingDetailDto? Booking)> CreateBookingAsync(int userId, CreateBookingDto dto);
        Task<SpResultDto> CancelBookingAsync(int bookingId, int userId, string? reason);
        Task<PagedResultDto<BookingListItemDto>> GetUserBookingsAsync(int userId, bool upcoming, int page, int pageSize);
        Task<BookingDetailDto?> GetBookingDetailAsync(int bookingId, int userId);

        Task<IEnumerable<AgendaItemDto>> GetVenueAgendaAsync(int venueId, int userId, DateTime from, DateTime to);
        Task<SpResultDto> MarkNoShowAsync(int bookingId, int userId);
    }
}
