using ApiCoreCUPPO.API.Authorization;
using ApiCoreCUPPO.API.Extensions;
using ApiCoreCUPPO.Application.DTOs.Booking;
using ApiCoreCUPPO.Application.DTOs.Payment;
using ApiCoreCUPPO.Application.Interfaces.IServices.Booking;
using ApiCoreCUPPO.Application.Interfaces.IServices.Payment;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ApiCoreCUPPO.API.Controllers
{
    /// <summary>Panel de dueño: agenda, pagos por verificar, cancelaciones y "no asistió".</summary>
    [Authorize(Policy = Policies.VerifiedOwner)]
    [Route("api/owner")]
    public class OwnerBookingsController : ApiControllerBase
    {
        private readonly IBookingService _bookingService;
        private readonly IPaymentService _paymentService;

        public OwnerBookingsController(IBookingService bookingService, IPaymentService paymentService)
        {
            _bookingService = bookingService;
            _paymentService = paymentService;
        }

        /// <summary>Reservas activas del complejo entre dos fechas (hora local; si no se indica "to", un día).</summary>
        [HttpGet("venues/{venueId:int}/agenda")]
        public async Task<IActionResult> GetAgenda(int venueId, [FromQuery] DateTime from, [FromQuery] DateTime? to)
        {
            if (from == default)
                return BadRequest(new { code = -2, message = "Indica la fecha inicial (from)." });

            return Ok(await _bookingService.GetVenueAgendaAsync(venueId, User.GetUserId(), from, to ?? from.Date.AddDays(1)));
        }

        /// <summary>Pagos por verificar de mis complejos (opcional: de un solo complejo).</summary>
        [HttpGet("payments/pending")]
        public async Task<IActionResult> GetPendingPayments([FromQuery] int? venueId)
        {
            return Ok(await _paymentService.GetPendingPaymentsAsync(User.GetUserId(), venueId));
        }

        /// <summary>Aprueba (la reserva queda confirmada) o rechaza (el jugador puede volver a pagar) un pago.</summary>
        [HttpPut("payments/{paymentId:int}/review")]
        public async Task<IActionResult> ReviewPayment(int paymentId, [FromBody] ReviewPaymentDto request)
        {
            return FromSpResult(await _paymentService.ReviewPaymentAsync(paymentId, User.GetUserId(), request));
        }

        /// <summary>El dueño cancela una reserva de su complejo (sin restricción de anticipación).</summary>
        [HttpPost("bookings/{bookingId:int}/cancel")]
        public async Task<IActionResult> CancelBooking(int bookingId, [FromBody] CancelBookingDto request)
        {
            return FromSpResult(await _bookingService.CancelBookingAsync(bookingId, User.GetUserId(), request.Reason));
        }

        /// <summary>Marca que el jugador no asistió (reserva confirmada que ya empezó).</summary>
        [HttpPut("bookings/{bookingId:int}/no-show")]
        public async Task<IActionResult> MarkNoShow(int bookingId)
        {
            return FromSpResult(await _bookingService.MarkNoShowAsync(bookingId, User.GetUserId()));
        }
    }
}
