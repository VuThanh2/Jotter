using Jotter.Domain;

namespace Jotter.Application;

// Tách khỏi UserManager: nhập sai mật khẩu note không được cộng vào bộ đếm khoá tài khoản.
public interface INotePasswordHasher
{
    NotePassword Hash(string password);

    bool Verify(string passwordHash, string password);
}
