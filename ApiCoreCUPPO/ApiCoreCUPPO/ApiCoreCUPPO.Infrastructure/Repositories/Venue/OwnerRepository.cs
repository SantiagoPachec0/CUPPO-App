using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.DTOs.Venue;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Venue;
using ApiCoreCUPPO.Infrastructure.Data;
using Dapper;
using System.Data;

namespace ApiCoreCUPPO.Infrastructure.Repositories.Venue
{
    public class OwnerRepository : IOwnerRepository
    {
        private readonly IDbConnectionFactory _db;

        public OwnerRepository(IDbConnectionFactory db)
        {
            _db = db;
        }

        public async Task<SpResultDto> RequestVerificationAsync(int userId, OwnerVerificationRequestDto dto, string? documentUrl)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Venue].[RequestOwnerVerification]", new
            {
                UserID = userId,
                dto.DocumentType,
                dto.DocumentNumber,
                dto.LegalName,
                dto.Phone,
                DocumentUrl = documentUrl
            });
        }

        public async Task<OwnerProfileDto?> GetOwnerProfileAsync(int userId)
        {
            using var connection = _db.CreateConnection();
            return await connection.QueryFirstOrDefaultAsync<OwnerProfileDto>(
                "[Venue].[GetOwnerProfile]", new { UserID = userId }, commandType: CommandType.StoredProcedure);
        }

        public async Task<IEnumerable<OwnerRequestDto>> GetOwnerRequestsAsync(int? verificationStatusId)
        {
            using var connection = _db.CreateConnection();
            return await connection.QueryAsync<OwnerRequestDto>(
                "[Venue].[GetOwnerRequests]", new { VerificationStatusID = verificationStatusId }, commandType: CommandType.StoredProcedure);
        }

        public async Task<SpResultDto> ReviewVerificationAsync(int userId, ReviewOwnerDto dto, int reviewerUserId)
        {
            using var connection = _db.CreateConnection();
            return await connection.ExecuteSpAsync("[Venue].[ReviewOwnerVerification]", new
            {
                UserID = userId,
                dto.VerificationStatusID,
                dto.ReviewNotes,
                ReviewerUserID = reviewerUserId
            });
        }
    }
}
