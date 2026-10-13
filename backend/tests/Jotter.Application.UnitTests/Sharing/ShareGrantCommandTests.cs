using Jotter.Domain;
using NSubstitute;
using Xunit;

namespace Jotter.Application.UnitTests;

// RevokeShare và ChangeSharePermission dùng chung cách định vị grant theo cặp (noteId, shareId) trên route.
public sealed class ShareGrantCommandTests
{
    private readonly Guid _ownerId = Guid.CreateVersion7();
    private readonly Guid _recipientId = Guid.CreateVersion7();
    private readonly Guid _noteId = Guid.CreateVersion7();
    private readonly ICurrentUser _currentUser = Substitute.For<ICurrentUser>();
    private readonly INoteAccessPolicy _accessPolicy = Substitute.For<INoteAccessPolicy>();
    private readonly IShareGrantRepository _shareGrants = Substitute.For<IShareGrantRepository>();
    private readonly IUnitOfWork _unitOfWork = Substitute.For<IUnitOfWork>();
    private readonly IRealtimeNotifier _realtime = Substitute.For<IRealtimeNotifier>();

    public ShareGrantCommandTests() => _currentUser.UserId.Returns(_ownerId);

    // Chủ note A không được thu hồi grant của note B chỉ bằng cách ghép shareId của B vào route của A.
    [Fact]
    public async Task Revoke_ShareBelongingToAnotherNote_IsNotFound_AndLeftUntouched()
    {
        GivenAccess(NoteAccessLevel.Owner);
        var foreignGrant = GivenGrant(noteId: Guid.CreateVersion7());

        var result = await RevokeAsync(foreignGrant.Id);

        Assert.Equal(ShareErrors.NotFound, result.Error);
        Assert.False(foreignGrant.IsRevoked);
        await _unitOfWork.DidNotReceive().SaveChangesAsync(Arg.Any<CancellationToken>());
    }

    [Theory]
    [InlineData(NoteAccessLevel.None, "ShareNotFound")]
    [InlineData(NoteAccessLevel.ReadOnly, "Forbidden")]
    [InlineData(NoteAccessLevel.Edit, "Forbidden")]
    public async Task Revoke_ByNonOwner_IsRejected(NoteAccessLevel level, string expectedCode)
    {
        GivenAccess(level);
        var grant = GivenGrant(_noteId);

        var result = await RevokeAsync(grant.Id);

        Assert.Equal(expectedCode, result.Error.Code);
        Assert.False(grant.IsRevoked);
    }

    [Fact]
    public async Task Revoke_TombstonesGrant_AndKicksRecipientAfterCommit()
    {
        GivenAccess(NoteAccessLevel.Owner);
        var grant = GivenGrant(_noteId);

        var result = await RevokeAsync(grant.Id);

        Assert.True(result.IsSuccess);
        Assert.True(grant.IsRevoked);
        Received.InOrder(() =>
        {
            _ = _unitOfWork.SaveChangesAsync(Arg.Any<CancellationToken>());
            _ = _realtime.AccessRevokedAsync(_noteId, _recipientId, Arg.Any<CancellationToken>());
        });
    }

    [Fact]
    public async Task ChangePermission_Downgrade_PushesNewPermissionToRecipient()
    {
        GivenAccess(NoteAccessLevel.Owner);
        var grant = GivenGrant(_noteId, SharePermission.Edit);

        await ChangePermissionAsync(grant.Id, SharePermission.ReadOnly);

        await _realtime.Received(1).PermissionChangedAsync(
            _noteId, _recipientId, SharePermission.ReadOnly, Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task ChangePermission_ToSamePermission_DoesNotPushSignal()
    {
        GivenAccess(NoteAccessLevel.Owner);
        var grant = GivenGrant(_noteId, SharePermission.Edit);

        await ChangePermissionAsync(grant.Id, SharePermission.Edit);

        await _realtime.DidNotReceive().PermissionChangedAsync(
            Arg.Any<Guid>(), Arg.Any<Guid>(), Arg.Any<SharePermission>(), Arg.Any<CancellationToken>());
    }

    private void GivenAccess(NoteAccessLevel level) =>
        _accessPolicy.GetAccessAsync(_ownerId, _noteId, Arg.Any<CancellationToken>()).Returns(TestData.Access(level));

    private ShareGrant GivenGrant(Guid noteId, SharePermission permission = SharePermission.Edit)
    {
        var grant = ShareGrant.Create(noteId, _ownerId, _recipientId, permission, TestData.Now).Value;
        _shareGrants.GetByIdAsync(grant.Id, Arg.Any<CancellationToken>()).Returns(grant);
        return grant;
    }

    private Task<Result> RevokeAsync(Guid shareId) =>
        new RevokeShareCommand(_currentUser, _accessPolicy, _shareGrants, _unitOfWork, _realtime, new FixedClock(TestData.Now))
            .ExecuteAsync(_noteId, shareId, TestData.Ct);

    private Task<Result<ChangeSharePermissionOutputDto>> ChangePermissionAsync(Guid shareId, SharePermission permission) =>
        new ChangeSharePermissionCommand(_currentUser, _accessPolicy, _shareGrants, _unitOfWork, _realtime)
            .ExecuteAsync(_noteId, shareId, new ChangeSharePermissionInputDto(permission), TestData.Ct);
}
