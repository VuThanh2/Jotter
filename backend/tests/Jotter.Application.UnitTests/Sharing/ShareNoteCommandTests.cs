using Jotter.Domain;
using NSubstitute;
using Xunit;

namespace Jotter.Application.UnitTests;

public sealed class ShareNoteCommandTests
{
    private readonly User _owner = TestData.NewUser("owner@jotter.app", "Chủ note");
    private readonly User _bob = TestData.NewUser("bob@jotter.app", "Bob");
    private readonly User _carol = TestData.NewUser("carol@jotter.app", "Carol");
    private readonly ICurrentUser _currentUser = Substitute.For<ICurrentUser>();
    private readonly INoteAccessPolicy _accessPolicy = Substitute.For<INoteAccessPolicy>();
    private readonly INoteRepository _notes = Substitute.For<INoteRepository>();
    private readonly IUserRepository _users = Substitute.For<IUserRepository>();
    private readonly IShareGrantRepository _shareGrants = Substitute.For<IShareGrantRepository>();
    private readonly IEmailSender _emailSender = Substitute.For<IEmailSender>();
    private readonly IUnitOfWork _unitOfWork = Substitute.For<IUnitOfWork>();
    private readonly Note _note;

    public ShareNoteCommandTests()
    {
        _note = TestData.NewNote(_owner.Id);
        _currentUser.UserId.Returns(_owner.Id);
        _accessPolicy.GetAccessAsync(_owner.Id, _note.Id, Arg.Any<CancellationToken>())
            .Returns(TestData.Access(NoteAccessLevel.Owner));
        _notes.GetByIdAsync(_note.Id, Arg.Any<CancellationToken>()).Returns(_note);
        _users.GetByIdAsync(_owner.Id, Arg.Any<CancellationToken>()).Returns(_owner);

        // Repository thật tra email không phân biệt hoa thường.
        _users.GetByEmailAsync(Arg.Any<string>(), Arg.Any<CancellationToken>()).Returns((User?)null);
        GivenRegistered(_owner, "owner@jotter.app");
        GivenRegistered(_bob, "bob@jotter.app", "BOB@jotter.app");
        GivenRegistered(_carol, "carol@jotter.app");
        _shareGrants.ExistsActiveAsync(_note.Id, _carol.Id, Arg.Any<CancellationToken>()).Returns(true);
    }

    [Fact]
    public async Task MixedBatch_GrantsValidRecipients_AndRejectsEachInvalidOneWithItsOwnReason()
    {
        var result = await ExecuteAsync(
            new ShareRecipientDto("bob@jotter.app", SharePermission.Edit),
            new ShareRecipientDto("khong-ton-tai", SharePermission.Edit),
            new ShareRecipientDto("owner@jotter.app", SharePermission.Edit),
            new ShareRecipientDto("BOB@jotter.app", SharePermission.ReadOnly),
            new ShareRecipientDto("carol@jotter.app", SharePermission.ReadOnly));

        var created = Assert.Single(result.Value.Created);
        Assert.Equal(_bob.Id, created.RecipientUserId);
        Assert.Equal(SharePermission.Edit, created.Permission);
        Assert.Equal(
            new[]
            {
                new RejectedRecipientDto("khong-ton-tai", ShareErrors.RecipientNotRegistered.Code),
                new RejectedRecipientDto("owner@jotter.app", ShareErrors.CannotShareWithSelf.Code),
                new RejectedRecipientDto("BOB@jotter.app", ShareErrors.DuplicateShare.Code),
                new RejectedRecipientDto("carol@jotter.app", ShareErrors.DuplicateShare.Code)
            },
            result.Value.Rejected);
        _shareGrants.Received(1).Add(Arg.Any<ShareGrant>());
        await _unitOfWork.Received(1).SaveChangesAsync(Arg.Any<CancellationToken>());
        await _emailSender.Received(1).SendNoteSharedAsync(
            Arg.Any<string>(), Arg.Any<string>(), Arg.Any<string>(), Arg.Any<string>(),
            Arg.Any<SharePermission>(), Arg.Any<CancellationToken>());
        await _emailSender.Received(1).SendNoteSharedAsync(
            "bob@jotter.app", "Bob", "Chủ note", _note.Title, SharePermission.Edit, Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task AllRecipientsRejected_FailsWithoutWritingOrNotifying()
    {
        var result = await ExecuteAsync(new ShareRecipientDto("khong-ton-tai@jotter.app", SharePermission.Edit));

        Assert.Equal(ShareErrors.RecipientNotRegistered.Code, result.Error.Code);
        Assert.True(result.Error.Details!.ContainsKey("rejected"));
        _shareGrants.DidNotReceive().Add(Arg.Any<ShareGrant>());
        await _unitOfWork.DidNotReceive().SaveChangesAsync(Arg.Any<CancellationToken>());
        await _emailSender.DidNotReceive().SendNoteSharedAsync(
            Arg.Any<string>(), Arg.Any<string>(), Arg.Any<string>(), Arg.Any<string>(),
            Arg.Any<SharePermission>(), Arg.Any<CancellationToken>());
    }

    private void GivenRegistered(User user, params string[] emails)
    {
        foreach (var email in emails)
        {
            _users.GetByEmailAsync(email, Arg.Any<CancellationToken>()).Returns(user);
        }
    }

    private Task<Result<ShareNoteOutputDto>> ExecuteAsync(params ShareRecipientDto[] recipients) =>
        new ShareNoteCommand(
                _currentUser, _accessPolicy, _notes, _users, _shareGrants, _emailSender, _unitOfWork,
                new FixedClock(TestData.Now))
            .ExecuteAsync(_note.Id, new ShareNoteInputDto(recipients), TestData.Ct);
}
