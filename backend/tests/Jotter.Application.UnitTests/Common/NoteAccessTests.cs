using Jotter.Domain;
using Xunit;

namespace Jotter.Application.UnitTests;

public sealed class NoteAccessTests
{
    [Fact]
    public void NoAccess_IsReportedAsNotFound_SoNoteExistenceIsNotLeaked()
    {
        var access = NoteAccess.None;

        Assert.Equal(NoteErrors.NotFound, access.EnsureCanView().Error);
        Assert.Equal(NoteErrors.NotFound, access.EnsureCanEditContent().Error);
        Assert.Equal(NoteErrors.NotFound, access.EnsureUnlockedOwner().Error);
    }

    // Thiếu mức quyền phải thắng trạng thái khoá: trả 423 sẽ dụ client mở khoá rồi vẫn bị chặn.
    [Fact]
    public void ReadOnlyRecipient_EditingLockedNote_IsForbiddenRatherThanLocked()
    {
        var access = TestData.Access(NoteAccessLevel.ReadOnly, isProtected: true);

        Assert.Equal(AccessErrors.Forbidden, access.EnsureCanEditContent().Error);
    }

    [Fact]
    public void LockedNote_ExposesMetadataOnly_EvenToOwner()
    {
        var access = TestData.Access(NoteAccessLevel.Owner, isProtected: true);

        Assert.True(access.EnsureCanView().IsSuccess);
        Assert.True(access.EnsureOwner().IsSuccess);
        Assert.Equal(AccessErrors.NoteLocked, access.EnsureCanReadContent().Error);
        Assert.Equal(AccessErrors.NoteLocked, access.EnsureUnlockedOwner().Error);
    }

    [Fact]
    public void ActiveUnlockSession_OpensContentOfProtectedNote()
    {
        var access = TestData.Access(NoteAccessLevel.ReadOnly, isProtected: true, unlocked: true);

        Assert.True(access.EnsureCanReadContent().IsSuccess);
    }

    // Edit là quyền trên nội dung; xoá, chia sẻ, bảo vệ là quyền trên vòng đời và chỉ thuộc chủ sở hữu.
    [Fact]
    public void EditRecipient_CanEditContent_ButCannotPerformOwnerActions()
    {
        var access = TestData.Access(NoteAccessLevel.Edit);

        Assert.True(access.EnsureCanEditContent().IsSuccess);
        Assert.Equal(AccessErrors.Forbidden, access.EnsureOwner().Error);
    }
}
