namespace Jotter.Domain;

// Tạo User đi qua UserManager.CreateAsync (băm mật khẩu, securityStamp) nên repository không có Add.
// Luôn trả về kèm Preferences.
public interface IUserRepository
{
    Task<User?> GetByIdAsync(Guid userId, CancellationToken ct);

    Task<User?> GetByEmailAsync(string email, CancellationToken ct);
}
