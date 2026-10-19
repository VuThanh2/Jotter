using Jotter.Application;
using Jotter.Domain;
using Microsoft.AspNetCore.Identity;

namespace Jotter.Infrastructure;

// Dùng lại thuật toán băm của Identity nhưng không đi qua UserManager, nên gõ sai mật khẩu note
// không bao giờ bị cộng vào bộ đếm khoá tài khoản.
public sealed class NotePasswordHasher : INotePasswordHasher
{
    private readonly PasswordHasher<Note> _hasher = new();

    // PasswordHasher mặc định không đọc tham số user, nên truyền null là an toàn.
    public NotePassword Hash(string password) => NotePassword.FromHash(_hasher.HashPassword(null!, password));

    public bool Verify(string passwordHash, string password) =>
        _hasher.VerifyHashedPassword(null!, passwordHash, password) is not PasswordVerificationResult.Failed;
}
