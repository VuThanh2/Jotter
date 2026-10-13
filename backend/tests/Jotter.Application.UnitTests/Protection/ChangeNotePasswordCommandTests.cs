using Jotter.Domain;
using NSubstitute;
using Xunit;

namespace Jotter.Application.UnitTests;

public sealed class ChangeNotePasswordCommandTests
{
    private static readonly DateTimeOffset ChangeTime = TestData.Now.AddMinutes(5);

    private readonly Guid _ownerId = Guid.CreateVersion7();
    private readonly ICurrentUser _currentUser = Substitute.For<ICurrentUser>();
    private readonly INoteAccessPolicy _accessPolicy = Substitute.For<INoteAccessPolicy>();
    private readonly INoteRepository _notes = Substitute.For<INoteRepository>();
    private readonly INoteUnlockSessionRepository _unlockSessions = Substitute.For<INoteUnlockSessionRepository>();
    private readonly INotePasswordHasher _passwordHasher = Substitute.For<INotePasswordHasher>();
    private readonly IUnitOfWork _unitOfWork = Substitute.For<IUnitOfWork>();
    private readonly Note _note;
    private readonly List<NoteUnlockSession> _sessionsOfEveryone;

    public ChangeNotePasswordCommandTests()
    {
        _note = TestData.NewProtectedNote(_ownerId, passwordHash: "old-hash");
        _sessionsOfEveryone =
        [
            _note.IssueUnlockSession(_ownerId, TestData.Now).Value,
            _note.IssueUnlockSession(Guid.CreateVersion7(), TestData.Now).Value
        ];

        _currentUser.UserId.Returns(_ownerId);
        _accessPolicy.GetAccessAsync(_ownerId, _note.Id, Arg.Any<CancellationToken>())
            .Returns(TestData.Access(NoteAccessLevel.Owner, isProtected: true));
        _notes.GetByIdAsync(_note.Id, Arg.Any<CancellationToken>()).Returns(_note);
        _unlockSessions.ListActiveByNoteAsync(_note.Id, ChangeTime, Arg.Any<CancellationToken>())
            .Returns(_sessionsOfEveryone);
        _passwordHasher.Verify("old-hash", "mat-khau-cu").Returns(true);
        _passwordHasher.Hash("mat-khau-moi").Returns(NotePassword.FromHash("new-hash"));
    }

    // Đổi mật khẩu phải đá phiên mở khoá trên MỌI thiết bị của MỌI người, kể cả người được chia sẻ.
    [Fact]
    public async Task CorrectCurrentPassword_ReplacesHash_AndEndsEveryUnlockSession()
    {
        var result = await ExecuteAsync("mat-khau-cu");

        Assert.True(result.IsSuccess);
        Assert.Equal("new-hash", _note.PasswordHash);
        Assert.All(_sessionsOfEveryone, session => Assert.False(session.IsActiveAt(ChangeTime)));
    }

    [Fact]
    public async Task WrongCurrentPassword_ChangesNothing()
    {
        var result = await ExecuteAsync("doan-bua");

        Assert.Equal(ProtectionErrors.InvalidNotePassword, result.Error);
        Assert.Equal("old-hash", _note.PasswordHash);
        Assert.All(_sessionsOfEveryone, session => Assert.True(session.IsActiveAt(ChangeTime)));
        await _unitOfWork.DidNotReceive().SaveChangesAsync(Arg.Any<CancellationToken>());
    }

    private Task<Result> ExecuteAsync(string currentPassword) =>
        new ChangeNotePasswordCommand(
                _currentUser, _accessPolicy, _notes, _unlockSessions, _passwordHasher, _unitOfWork,
                new FixedClock(ChangeTime))
            .ExecuteAsync(
                _note.Id,
                new ChangeNotePasswordInputDto(currentPassword, "mat-khau-moi", "mat-khau-moi"),
                TestData.Ct);
}
