using ApiCoreCUPPO.API.Extensions;
using ApiCoreCUPPO.Application.DTOs.Booking;
using ApiCoreCUPPO.Application.DTOs.Payment;
using ApiCoreCUPPO.Application.Interfaces.IServices.Booking;
using ApiCoreCUPPO.Application.Interfaces.IServices.Payment;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ApiCoreCUPPO.API.Controllers
{
    /// <summary>Reservas del jugador: disponibilidad, reservar, pagar y cancelar.</summary>
    [Route("api")]
    public class BookingsController : ApiControllerBase
    {
        private readonly IBookingService _bookingService;
        private readonly IPaymentService _paymentService;

        public BookingsController(IBookingService bookingService, IPaymentService paymentService)
        {
            _bookingService = bookingService;
            _paymentService = paymentService;
        }

        /// <summary>Turnos de una cancha para una fecha (público). Horas locales de Venezuela.</summary>
        [HttpGet("courts/{courtId:int}/availability")]
        public async Task<IActionResult> GetAvailability(int courtId, [FromQuery] DateTime date)
        {
            if (date == default)
                return BadRequest(new { code = -2, message = "Indica la fecha (date=yyyy-MM-dd)." });

            return Ok(await _bookingService.GetAvailabilityAsync(courtId, date));
        }

        /// <summary>
        /// Reserva una cancha. Queda pendiente de pago: la respuesta trae las cuentas del complejo
        /// y el límite para pagar (expiresAt, UTC).
        /// </summary>
        [Authorize]
        [HttpPost("bookings")]
        public async Task<IActionResult> CreateBooking([FromBody] CreateBookingDto request)
        {
            var (result, booking) = await _bookingService.CreateBookingAsync(User.GetUserId(), request);
            if (!result.IsSuccess && result.CodeResult == -11)
                return Conflict(new { code = result.CodeResult, message = result.MessageResult });

            return FromSpResult(result, booking);
        }

        /// <summary>Mis reservas. scope: upcoming (por jugar) o past (historial).</summary>
        [Authorize]
        [HttpGet("bookings/me")]
        public async Task<IActionResult> GetMyBookings([FromQuery] string scope = "upcoming", [FromQuery] int page = 1, [FromQuery] int pageSize = 20)
        {
            var upcoming = !string.Equals(scope, "past", StringComparison.OrdinalIgnoreCase);
            return Ok(await _bookingService.GetUserBookingsAsync(User.GetUserId(), upcoming, page, pageSize));
        }

        /// <summary>Detalle de una reserva (para el jugador o el dueño del complejo), con datos para pagar y pagos registrados.</summary>
        [Authorize]
        [HttpGet("bookings/{bookingId:int}")]
        public async Task<IActionResult> GetBooking(int bookingId)
        {
            var booking = await _bookingService.GetBookingDetailAsync(bookingId, User.GetUserId());
            return booking is null ? NotFound(new { code = 0, message = "La reserva no existe." }) : Ok(booking);
        }

        /// <summary>Cancela la reserva. Si está confirmada, solo con la anticipación que fija el complejo.</summary>
        [Authorize]
        [HttpPost("bookings/{bookingId:int}/cancel")]
        public async Task<IActionResult> CancelBooking(int bookingId, [FromBody] CancelBookingDto request)
        {
            return FromSpResult(await _bookingService.CancelBookingAsync(bookingId, User.GetUserId(), request.Reason));
        }

        /// <summary>
        /// Registra el pago de una reserva (multipart): campos del pago + "receipt" opcional con la
        /// foto del comprobante. La reserva pasa a "pago por verificar".
        /// </summary>
        [Authorize]
        [HttpPost("bookings/{bookingId:int}/payments")]
        [Consumes("multipart/form-data")]
        [RequestSizeLimit(UploadLimits.MaxRequestBytes)]
        public async Task<IActionResult> RegisterPayment(int bookingId, [FromForm] CreatePaymentDto request, IFormFile? receipt)
        {
            if (receipt is null)
                return FromSpResult(await _paymentService.RegisterPaymentAsync(bookingId, User.GetUserId(), request, null));

            await using var stream = receipt.OpenReadStream();
            return FromSpResult(await _paymentService.RegisterPaymentAsync(bookingId, User.GetUserId(), request, receipt.ToUploadDto(stream)));
        }

        /// <summary>Foto del comprobante (solo para quien pagó y el dueño del complejo).</summary>
        [Authorize]
        [HttpGet("payments/{paymentId:int}/receipt")]
        public async Task<IActionResult> GetReceipt(int paymentId)
        {
            var receipt = await _paymentService.OpenReceiptAsync(paymentId, User.GetUserId());
            return receipt is null
                ? NotFound(new { code = 0, message = "Comprobante no disponible." })
                : File(receipt.Value.Content, receipt.Value.ContentType);
        }
    }
}
