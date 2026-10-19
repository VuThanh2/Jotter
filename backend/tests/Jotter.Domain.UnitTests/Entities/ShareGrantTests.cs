using Xunit;

namespace Jotter.Domain.UnitTests;

public sealed class ShareGrantTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 12, 8, 0, 0, TimeSpan.Zero);
    private static readonly Guid NoteId = Guid.CreateVersion7();
    private static readonly Guid OwnerId = Guid.CreateVersion7();
    private static readonly Guid RecipientId = Guid.CreateVersion7();

    [Fact]
    public void Create_RejectsSharingWithOwner()
    {
        var result = ShareGrant.Create(NoteId, OwnerId, OwnerId, SharePermission.Edit, Now);

        Assert.Equal(ShareErrors.CannotShareWithSelf, result.Error);
    }

    [Fact]
    public void Create_RejectsUndefinedPermission()
    {
        var result = ShareGrant.Create(NoteId, OwnerId, RecipientId, (SharePermission)99, Now);

        Assert.Equal(ShareErrors.InvalidPermission, result.Error);
    }

    [Fact]
    public void Revoke_IsTombstone_AndBlocksPermissionChange()
    {
        var grant = ShareGrant.Create(NoteId, OwnerId, RecipientId, SharePermission.Edit, Now).Value;

        grant.Revoke(Now);

        Assert.True(grant.IsRevoked);
        Assert.Equal(ShareErrors.NotFound, grant.ChangePermission(SharePermission.ReadOnly).Error);
        Assert.Equal(ShareErrors.NotFound, grant.Revoke(Now).Error);
    }
}
