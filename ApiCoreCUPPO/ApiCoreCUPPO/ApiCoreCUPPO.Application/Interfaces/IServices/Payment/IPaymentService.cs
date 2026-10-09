using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Payment;

namespace ApiCoreCUPPO.Application.Interfaces.IServices.Payment
{
    public interface IPaymentService
    {
        /// <summary>Registra el pago de una reserva; la foto del comprobante es opcional y se guarda como archivo privado.</summary>
        Task<SpResultDto> RegisterPaymentAsync(int bookingId, int userId, CreatePaymentDto dto, UploadFileDto? receipt);
        Task<SpResultDto> ReviewPaymentAsync(int paymentId, int reviewerUserId, ReviewPaymentDto dto);
        Task<IEnumerable<PendingPaymentDto>> GetPendingPaymentsAsync(int userId, int? venueId);

        /// <summary>Abre el comprobante si el usuario es quien pagó o el dueño del complejo.</summary>
        Task<(Stream Content, string ContentType)?> OpenReceiptAsync(int paymentId, int userId);
    }
}
