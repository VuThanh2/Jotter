using Jotter.Domain;
using Microsoft.AspNetCore.Identity;
using NSubstitute;
using Xunit;

namespace Jotter.Application.UnitTests;

internal static class TestData
{
    public static readonly DateTimeOffset Now = new(2026, 10, 13, 8, 0, 0, TimeSpan.Zero);

    public static CancellationToken Ct => TestContext.Current.CancellationToken;

    public static Note NewNote(Guid ownerId, string title = "Tiêu đề", string content = "Nội dung") =>
        Note.Create(Guid.CreateVersion7(), ownerId, title, content, Now).Value;

    public static Note NewProtectedNote(Guid ownerId, string passwordHash = "note-hash")
    {
        var note = NewNote(ownerId);
        note.EnableProtection(NotePassword.FromHash(passwordHash));
        return note;
    }

    public static User NewUser(string email, string displayName = "Người dùng") =>
        User.Create(email, displayName, Now).Value;

    public static NoteAccess Access(NoteAccessLevel level, bool isProtected = false, bool unlocked = false) =>
        new(level, isProtected, unlocked);

    // Các method của UserManager đều virtual nên thay thế được; constructor chỉ bắt buộc store.
    public static UserManager<User> NewUserManager() =>
        Substitute.For<UserManager<User>>(
            Substitute.For<IUserStore<User>>(), null!, null!, null!, null!, null!, null!, null!, null!);
}
