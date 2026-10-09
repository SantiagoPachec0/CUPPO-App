using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Payment;

namespace ApiCoreCUPPO.Application.Interfaces.IRepository.Payment
{
    public interface IPaymentRepository
    {
        Task<SpResultDto> InsertPaymentAsync(int bookingId, int userId, CreatePaymentDto dto, string? receiptUrl);
        Task<SpResultDto> ReviewPaymentAsync(int paymentId, int reviewerUserId, ReviewPaymentDto dto);
        Task<IEnumerable<PendingPaymentDto>> GetPendingPaymentsAsync(int userId, int? venueId);

        /// <summary>Clave privada del comprobante si el usuario es quien pagó o el dueño; null si no.</summary>
        Task<string?> GetReceiptKeyAsync(int paymentId, int userId);
    }
}
