using Jotter.Domain;
using NSubstitute;
using Xunit;

namespace Jotter.Application.UnitTests;

public sealed class DownloadAttachmentQueryTests
{
    private readonly Guid _userId = Guid.CreateVersion7();
    private readonly Guid _noteId = Guid.CreateVersion7();
    private readonly Guid _attachmentId = Guid.CreateVersion7();
    private readonly ICurrentUser _currentUser = Substitute.For<ICurrentUser>();
    private readonly INoteAccessPolicy _accessPolicy = Substitute.For<INoteAccessPolicy>();
    private readonly INoteQueryService _noteQueries = Substitute.For<INoteQueryService>();
    private readonly IFileStorage _storage = Substitute.For<IFileStorage>();

    public DownloadAttachmentQueryTests()
    {
        _currentUser.UserId.Returns(_userId);
        _noteQueries.FindAttachmentAsync(_attachmentId, Arg.Any<CancellationToken>())
            .Returns(new StoredAttachment(_noteId, "a.pdf", "application/pdf", 10, "attachments/key"));
    }

    // Người lạ đoán được attachmentId cũng không được biết tệp đó tồn tại, và bytes không bao giờ được mở.
    [Fact]
    public async Task UserWithoutAccessToOwningNote_GetsAttachmentNotFound()
    {
        GivenAccess(NoteAccess.None);

        var result = await ExecuteAsync();

        Assert.Equal(NoteErrors.AttachmentNotFound, result.Error);
        await _storage.DidNotReceive().OpenReadAsync(Arg.Any<string>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task AttachmentOfLockedNote_IsNotStreamed()
    {
        GivenAccess(TestData.Access(NoteAccessLevel.ReadOnly, isProtected: true));

        var result = await ExecuteAsync();

        Assert.Equal(AccessErrors.NoteLocked, result.Error);
        await _storage.DidNotReceive().OpenReadAsync(Arg.Any<string>(), Arg.Any<CancellationToken>());
    }

    private void GivenAccess(NoteAccess access) =>
        _accessPolicy.GetAccessAsync(_userId, _noteId, Arg.Any<CancellationToken>()).Returns(access);

    private Task<Result<DownloadAttachmentOutputDto>> ExecuteAsync() =>
        new DownloadAttachmentQuery(_currentUser, _accessPolicy, _noteQueries, _storage)
            .ExecuteAsync(_attachmentId, TestData.Ct);
}
