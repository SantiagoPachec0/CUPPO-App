using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Payment;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Payment;
using ApiCoreCUPPO.Application.Interfaces.IServices.Common;
using ApiCoreCUPPO.Application.Interfaces.IServices.Payment;
using ApiCoreCUPPO.Application.Services.Common;

namespace ApiCoreCUPPO.Application.Services.Payment
{
    public class PaymentService : IPaymentService
    {
        private readonly IPaymentRepository _paymentRepository;
        private readonly IFileStorage _storage;

        public PaymentService(IPaymentRepository paymentRepository, IFileStorage storage)
        {
            _paymentRepository = paymentRepository;
            _storage = storage;
        }

        public Task<SpResultDto> RegisterPaymentAsync(int bookingId, int userId, CreatePaymentDto dto, UploadFileDto? receipt)
        {
            if (receipt is null)
                return _paymentRepository.InsertPaymentAsync(bookingId, userId, dto, receiptUrl: null);

            // El comprobante es privado: solo lo ven el jugador y el dueño
            return PhotoUploader.UploadAsync(_storage, receipt, "receipts", isPrivate: true,
                url => _paymentRepository.InsertPaymentAsync(bookingId, userId, dto, url));
        }

        public Task<SpResultDto> ReviewPaymentAsync(int paymentId, int reviewerUserId, ReviewPaymentDto dto)
            => _paymentRepository.ReviewPaymentAsync(paymentId, reviewerUserId, dto);

        public Task<IEnumerable<PendingPaymentDto>> GetPendingPaymentsAsync(int userId, int? venueId)
            => _paymentRepository.GetPendingPaymentsAsync(userId, venueId);

        public async Task<(Stream Content, string ContentType)?> OpenReceiptAsync(int paymentId, int userId)
        {
            var key = await _paymentRepository.GetReceiptKeyAsync(paymentId, userId);
            if (key is null)
                return null;

            var stream = _storage.OpenPrivate(key);
            if (stream is null)
                return null;

            var contentType = Path.GetExtension(key).ToLowerInvariant() switch
            {
                ".png" => "image/png",
                ".webp" => "image/webp",
                _ => "image/jpeg"
            };
            return (stream, contentType);
        }
    }
}
