using Jotter.Domain;
using NSubstitute;
using Xunit;

namespace Jotter.Application.UnitTests;

public sealed class UnlockNoteCommandTests
{
    private static readonly DateTimeOffset UnlockTime = TestData.Now.AddMinutes(5);

    private readonly Guid _recipientId = Guid.CreateVersion7();
    private readonly ICurrentUser _currentUser = Substitute.For<ICurrentUser>();
    private readonly INoteAccessPolicy _accessPolicy = Substitute.For<INoteAccessPolicy>();
    private readonly INoteRepository _notes = Substitute.For<INoteRepository>();
    private readonly INoteUnlockSessionRepository _unlockSessions = Substitute.For<INoteUnlockSessionRepository>();
    private readonly INotePasswordHasher _passwordHasher = Substitute.For<INotePasswordHasher>();
    private readonly IUnitOfWork _unitOfWork = Substitute.For<IUnitOfWork>();
    private readonly Note _note = TestData.NewProtectedNote(Guid.CreateVersion7(), passwordHash: "note-hash");

    public UnlockNoteCommandTests()
    {
        _currentUser.UserId.Returns(_recipientId);
        _accessPolicy.GetAccessAsync(_recipientId, _note.Id, Arg.Any<CancellationToken>())
            .Returns(TestData.Access(NoteAccessLevel.ReadOnly, isProtected: true));
        _notes.GetByIdAsync(_note.Id, Arg.Any<CancellationToken>()).Returns(_note);
        _passwordHasher.Verify("note-hash", "dung-mat-khau").Returns(true);
    }

    [Fact]
    public async Task WrongPassword_IssuesNoSession()
    {
        var result = await ExecuteAsync("sai-mat-khau");

        Assert.Equal(ProtectionErrors.InvalidNotePassword, result.Error);
        _unlockSessions.DidNotReceive().Add(Arg.Any<NoteUnlockSession>());
        await _unitOfWork.DidNotReceive().SaveChangesAsync(Arg.Any<CancellationToken>());
    }

    // Người được chia sẻ mở khoá bằng chính mật khẩu note; phiên cũ bị thay để luôn chỉ có một phiên sống.
    [Fact]
    public async Task CorrectPassword_IssuesSessionForCaller_AndReplacesPreviousOne()
    {
        var previous = _note.IssueUnlockSession(_recipientId, TestData.Now).Value;
        _unlockSessions.ListActiveAsync(_note.Id, _recipientId, UnlockTime, Arg.Any<CancellationToken>())
            .Returns(new List<NoteUnlockSession> { previous });

        var result = await ExecuteAsync("dung-mat-khau");

        Assert.Equal(UnlockTime + NoteUnlockSession.Lifetime, result.Value.ExpiresAt);
        Assert.False(previous.IsActiveAt(UnlockTime));
        _unlockSessions.Received(1).Add(Arg.Is<NoteUnlockSession>(s =>
            s.Id == result.Value.UnlockSessionId && s.UserId == _recipientId && s.NoteId == _note.Id));
    }

    private Task<Result<UnlockNoteOutputDto>> ExecuteAsync(string password) =>
        new UnlockNoteCommand(
                _currentUser, _accessPolicy, _notes, _unlockSessions, _passwordHasher, _unitOfWork,
                new FixedClock(UnlockTime))
            .ExecuteAsync(_note.Id, new UnlockNoteInputDto(password), TestData.Ct);
}
