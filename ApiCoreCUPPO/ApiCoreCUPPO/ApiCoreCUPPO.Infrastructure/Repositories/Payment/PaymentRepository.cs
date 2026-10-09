using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Payment;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Payment;
using ApiCoreCUPPO.Infrastructure.Data;
using Dapper;
using System.Data;

namespace ApiCoreCUPPO.Infrastructure.Repositories.Payment
{
    public class PaymentRepository : IPaymentRepository
    {
        private readonly IDbConnectionFactory _db;

        public PaymentRepository(IDbConnectionFactory db)
        {
            _db = db;
        }

        public async Task<SpResultDto> InsertPaymentAsync(int bookingId, int userId, CreatePaymentDto dto, string? receiptUrl)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Payment].[InsertPayment]", new
            {
                BookingID = bookingId,
                UserID = userId,
                dto.PaymentMethodID,
                dto.VenuePaymentAccountID,
                dto.AmountPaid,
                PaymentDate = dto.PaymentDate.Date,
                dto.Reference,
                ReceiptUrl = receiptUrl,
                dto.PayerName,
                dto.PayerDocument,
                dto.PayerPhone
            });
        }

        public async Task<SpResultDto> ReviewPaymentAsync(int paymentId, int reviewerUserId, ReviewPaymentDto dto)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Payment].[ReviewPayment]", new
            {
                PaymentID = paymentId,
                ReviewerUserID = reviewerUserId,
                dto.Approve,
                dto.RejectionReason
            });
        }

        public async Task<IEnumerable<PendingPaymentDto>> GetPendingPaymentsAsync(int userId, int? venueId)
        {
            using var connection = _db.CreateConnection();
            return await connection.QueryAsync<PendingPaymentDto>(
                "[Payment].[GetPendingPayments]", new { UserID = userId, VenueID = venueId }, commandType: CommandType.StoredProcedure);
        }

        public async Task<string?> GetReceiptKeyAsync(int paymentId, int userId)
        {
            using var connection = _db.CreateConnection();
            return await connection.QueryFirstOrDefaultAsync<string>(
                "[Payment].[GetPaymentReceipt]", new { PaymentID = paymentId, UserID = userId }, commandType: CommandType.StoredProcedure);
        }
    }
}
