using Jotter.Domain;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace Jotter.Infrastructure;

public sealed class UserRepository(AppDbContext db, ILookupNormalizer normalizer) : IUserRepository
{
    public Task<User?> GetByIdAsync(Guid userId, CancellationToken ct) =>
        WithPreferences().FirstOrDefaultAsync(u => u.Id == userId, ct);

    // Tra theo NormalizedEmail bằng đúng bộ chuẩn hoá của Identity để khớp cách UserManager lưu.
    public Task<User?> GetByEmailAsync(string email, CancellationToken ct)
    {
        var normalizedEmail = normalizer.NormalizeEmail(email.Trim());
        return WithPreferences().FirstOrDefaultAsync(u => u.NormalizedEmail == normalizedEmail, ct);
    }

    private IQueryable<User> WithPreferences() => db.Users.Include(u => u.Preferences);
}
