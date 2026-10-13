using Jotter.Domain;
using NSubstitute;
using Xunit;

namespace Jotter.Application.UnitTests;

public sealed class DeleteNoteCommandTests
{
    private readonly Guid _ownerId = Guid.CreateVersion7();
    private readonly ICurrentUser _currentUser = Substitute.For<ICurrentUser>();
    private readonly INoteAccessPolicy _accessPolicy = Substitute.For<INoteAccessPolicy>();
    private readonly INoteRepository _notes = Substitute.For<INoteRepository>();
    private readonly IShareGrantRepository _shareGrants = Substitute.For<IShareGrantRepository>();
    private readonly IUnitOfWork _unitOfWork = Substitute.For<IUnitOfWork>();
    private readonly IRealtimeNotifier _realtime = Substitute.For<IRealtimeNotifier>();

    public DeleteNoteCommandTests() => _currentUser.UserId.Returns(_ownerId);

    [Fact]
    public async Task Owner_TombstonesNote_RevokesEveryShare_AndKicksRecipientsAfterCommit()
    {
        var note = TestData.NewNote(_ownerId);
        var grants = new List<ShareGrant>
        {
            ShareGrant.Create(note.Id, _ownerId, Guid.CreateVersion7(), SharePermission.Edit, TestData.Now).Value,
            ShareGrant.Create(note.Id, _ownerId, Guid.CreateVersion7(), SharePermission.ReadOnly, TestData.Now).Value
        };
        GivenNote(note, NoteAccessLevel.Owner);
        _shareGrants.ListActiveByNoteAsync(note.Id, Arg.Any<CancellationToken>()).Returns(grants);

        var result = await CreateCommand().ExecuteAsync(note.Id, TestData.Ct);

        Assert.True(result.IsSuccess);
        Assert.True(note.IsDeleted);
        Assert.All(grants, grant => Assert.True(grant.IsRevoked));
        Received.InOrder(() =>
        {
            _ = _unitOfWork.SaveChangesAsync(Arg.Any<CancellationToken>());
            _ = _realtime.AccessRevokedAsync(note.Id, grants[0].RecipientUserId, Arg.Any<CancellationToken>());
            _ = _realtime.AccessRevokedAsync(note.Id, grants[1].RecipientUserId, Arg.Any<CancellationToken>());
        });
    }

    [Fact]
    public async Task EditRecipient_CannotDeleteNote()
    {
        var note = TestData.NewNote(Guid.CreateVersion7());
        GivenNote(note, NoteAccessLevel.Edit);

        var result = await CreateCommand().ExecuteAsync(note.Id, TestData.Ct);

        Assert.Equal(AccessErrors.Forbidden, result.Error);
        Assert.False(note.IsDeleted);
        await _unitOfWork.DidNotReceive().SaveChangesAsync(Arg.Any<CancellationToken>());
    }

    private DeleteNoteCommand CreateCommand() =>
        new(_currentUser, _accessPolicy, _notes, _shareGrants, _unitOfWork, _realtime, new FixedClock(TestData.Now));

    private void GivenNote(Note note, NoteAccessLevel level)
    {
        _accessPolicy.GetAccessAsync(_ownerId, note.Id, Arg.Any<CancellationToken>()).Returns(TestData.Access(level));
        _notes.GetByIdAsync(note.Id, Arg.Any<CancellationToken>()).Returns(note);
    }
}
