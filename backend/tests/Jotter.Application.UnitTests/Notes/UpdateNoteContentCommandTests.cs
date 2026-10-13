using Jotter.Domain;
using NSubstitute;
using Xunit;

namespace Jotter.Application.UnitTests;

public sealed class UpdateNoteContentCommandTests
{
    private static readonly DateTimeOffset EditTime = TestData.Now.AddMinutes(10);

    private readonly Guid _userId = Guid.CreateVersion7();
    private readonly ICurrentUser _currentUser = Substitute.For<ICurrentUser>();
    private readonly INoteAccessPolicy _accessPolicy = Substitute.For<INoteAccessPolicy>();
    private readonly INoteRepository _notes = Substitute.For<INoteRepository>();
    private readonly INoteUnlockSessionRepository _unlockSessions = Substitute.For<INoteUnlockSessionRepository>();
    private readonly IUnitOfWork _unitOfWork = Substitute.For<IUnitOfWork>();
    private readonly IRealtimeNotifier _realtime = Substitute.For<IRealtimeNotifier>();

    public UpdateNoteContentCommandTests() => _currentUser.UserId.Returns(_userId);

    [Fact]
    public async Task StaleBaseVersion_ReturnsServerCopyForConflictCopy_WithoutWriting()
    {
        var note = GivenNote(TestData.NewNote(_userId, "Tiêu đề", "Bản gốc"), NoteAccessLevel.Owner);
        note.UpdateContent(baseVersion: 1, "Tiêu đề", "Bản sửa ở máy khác", TestData.Now);

        var result = await CreateCommand().ExecuteAsync(
            note.Id,
            new UpdateNoteContentInputDto(BaseVersion: 1, "Tiêu đề", "Bản soạn offline"),
            TestData.Ct);

        Assert.Equal(NoteErrors.VersionConflict.Code, result.Error.Code);
        var serverNote = Assert.IsType<ServerNoteDto>(result.Error.Details!["serverNote"]);
        Assert.Equal("Bản sửa ở máy khác", serverNote.Content);
        Assert.Equal(2, serverNote.Version);
        await _unitOfWork.DidNotReceive().SaveChangesAsync(Arg.Any<CancellationToken>());
        await _realtime.DidNotReceive().NoteChangedAsync(
            Arg.Any<Guid>(), Arg.Any<long>(), Arg.Any<Guid>(), Arg.Any<CancellationToken>());
    }

    // Request đã lưu nhưng response rớt, client gửi lại với baseVersion cũ: không được sinh Conflict Copy giả.
    [Fact]
    public async Task RetryOfAlreadySavedContent_SucceedsWithoutBumpingVersionOrSignalling()
    {
        var note = GivenNote(TestData.NewNote(_userId, "Tiêu đề", "Bản gốc"), NoteAccessLevel.Owner);
        note.UpdateContent(baseVersion: 1, "Tiêu đề", "Bản đã lưu", TestData.Now);

        var result = await CreateCommand().ExecuteAsync(
            note.Id,
            new UpdateNoteContentInputDto(BaseVersion: 1, "Tiêu đề", "Bản đã lưu"),
            TestData.Ct);

        Assert.Equal(2, result.Value.Version);
        await _realtime.DidNotReceive().NoteChangedAsync(
            Arg.Any<Guid>(), Arg.Any<long>(), Arg.Any<Guid>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task SuccessfulEdit_BumpsVersion_AndSignalsOnlyAfterCommit()
    {
        var note = GivenNote(TestData.NewNote(_userId), NoteAccessLevel.Edit);

        var result = await CreateCommand().ExecuteAsync(
            note.Id,
            new UpdateNoteContentInputDto(BaseVersion: 1, "Tiêu đề", "Nội dung mới"),
            TestData.Ct);

        Assert.Equal(2, result.Value.Version);
        Received.InOrder(() =>
        {
            _ = _unitOfWork.SaveChangesAsync(Arg.Any<CancellationToken>());
            _ = _realtime.NoteChangedAsync(note.Id, 2, _userId, Arg.Any<CancellationToken>());
        });
    }

    [Fact]
    public async Task ProtectedNote_SuccessfulSave_SlidesUnlockSession()
    {
        var note = GivenNote(TestData.NewProtectedNote(_userId), NoteAccessLevel.Owner, isProtected: true);
        var session = GivenActiveUnlockSession(note);

        await CreateCommand().ExecuteAsync(
            note.Id,
            new UpdateNoteContentInputDto(BaseVersion: 1, "Tiêu đề", "Nội dung mới"),
            TestData.Ct);

        Assert.Equal(EditTime + NoteUnlockSession.Lifetime, session.ExpiresAt);
    }

    [Fact]
    public async Task ProtectedNote_RejectedSave_DoesNotExtendUnlockSession()
    {
        var note = GivenNote(TestData.NewProtectedNote(_userId), NoteAccessLevel.Owner, isProtected: true);
        var session = GivenActiveUnlockSession(note);
        var originalExpiry = session.ExpiresAt;

        await CreateCommand().ExecuteAsync(
            note.Id,
            new UpdateNoteContentInputDto(BaseVersion: 99, "Tiêu đề", "Nội dung mới"),
            TestData.Ct);

        Assert.Equal(originalExpiry, session.ExpiresAt);
    }

    private UpdateNoteContentCommand CreateCommand() =>
        new(_currentUser, _accessPolicy, _notes, _unlockSessions, _unitOfWork, _realtime, new FixedClock(EditTime));

    private Note GivenNote(Note note, NoteAccessLevel level, bool isProtected = false)
    {
        _accessPolicy.GetAccessAsync(_userId, note.Id, Arg.Any<CancellationToken>())
            .Returns(TestData.Access(level, isProtected, unlocked: isProtected));
        _notes.GetByIdAsync(note.Id, Arg.Any<CancellationToken>()).Returns(note);
        return note;
    }

    private NoteUnlockSession GivenActiveUnlockSession(Note note)
    {
        var session = note.IssueUnlockSession(_userId, TestData.Now).Value;
        _unlockSessions.ListActiveAsync(note.Id, _userId, EditTime, Arg.Any<CancellationToken>())
            .Returns(new List<NoteUnlockSession> { session });
        return session;
    }
}
