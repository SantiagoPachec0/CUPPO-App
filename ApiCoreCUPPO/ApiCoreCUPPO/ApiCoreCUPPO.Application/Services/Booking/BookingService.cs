using ApiCoreCUPPO.Application.DTOs.Booking;
using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Booking;
using ApiCoreCUPPO.Application.Interfaces.IServices.Booking;

namespace ApiCoreCUPPO.Application.Services.Booking
{
    public class BookingService : IBookingService
    {
        private const int MaxAgendaDays = 31;

        private readonly IBookingRepository _bookingRepository;

        public BookingService(IBookingRepository bookingRepository)
        {
            _bookingRepository = bookingRepository;
        }

        public Task<IEnumerable<AvailabilitySlotDto>> GetAvailabilityAsync(int courtId, DateTime date)
            => _bookingRepository.GetAvailabilityAsync(courtId, date.Date);

        public async Task<(SpResultDto Result, BookingDetailDto? Booking)> CreateBookingAsync(int userId, CreateBookingDto dto)
        {
            var result = await _bookingRepository.CreateBookingAsync(userId, dto);
            if (!result.IsSuccess)
                return (result, null);

            return (result, await _bookingRepository.GetBookingDetailAsync(result.CodeResult, userId));
        }

        public Task<SpResultDto> CancelBookingAsync(int bookingId, int userId, string? reason)
            => _bookingRepository.CancelBookingAsync(bookingId, userId, reason);

        public async Task<PagedResultDto<BookingListItemDto>> GetUserBookingsAsync(int userId, bool upcoming, int page, int pageSize)
        {
            page = Math.Max(page, 1);
            pageSize = Math.Clamp(pageSize, 1, 50);

            var items = (await _bookingRepository.GetUserBookingsAsync(userId, upcoming, page, pageSize)).ToList();
            return new PagedResultDto<BookingListItemDto>
            {
                Items = items,
                Page = page,
                PageSize = pageSize,
                TotalCount = items.FirstOrDefault()?.TotalCount ?? 0
            };
        }

        public Task<BookingDetailDto?> GetBookingDetailAsync(int bookingId, int userId)
            => _bookingRepository.GetBookingDetailAsync(bookingId, userId);

        public Task<IEnumerable<AgendaItemDto>> GetVenueAgendaAsync(int venueId, int userId, DateTime from, DateTime to)
        {
            if (to <= from || (to - from).TotalDays > MaxAgendaDays)
                to = from.AddDays(1);

            return _bookingRepository.GetVenueAgendaAsync(venueId, userId, from, to);
        }

        public Task<SpResultDto> MarkNoShowAsync(int bookingId, int userId)
            => _bookingRepository.MarkNoShowAsync(bookingId, userId);
    }
}
