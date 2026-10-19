using Jotter.Domain;
using Microsoft.EntityFrameworkCore;

namespace Jotter.Infrastructure;

public sealed class VerificationCodeRepository(AppDbContext db) : IVerificationCodeRepository
{
    public Task<VerificationCode?> GetPendingAsync(Guid userId, OtpPurpose purpose, CancellationToken ct) =>
        Latest(userId, purpose)
            .Where(c => c.ConsumedAt == null && c.InvalidatedAt == null)
            .FirstOrDefaultAsync(ct);

    public Task<VerificationCode?> GetLatestAsync(Guid userId, OtpPurpose purpose, CancellationToken ct) =>
        Latest(userId, purpose).FirstOrDefaultAsync(ct);

    public void Add(VerificationCode code) => db.VerificationCodes.Add(code);

    private IQueryable<VerificationCode> Latest(Guid userId, OtpPurpose purpose) =>
        db.VerificationCodes
            .Where(c => c.UserId == userId && c.Purpose == purpose)
            .OrderByDescending(c => c.CreatedAt);
}
