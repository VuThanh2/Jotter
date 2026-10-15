using Jotter.Application;
using Jotter.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Xunit;
using static Jotter.Infrastructure.IntegrationTests.TestData;

namespace Jotter.Infrastructure.IntegrationTests;

// Metadata ở Postgres, bytes ở kho lưu trữ: hai nơi phải luôn khớp nhau, và quyền phải được kiểm ở mỗi lần tải.
public sealed class AttachmentAndAvatarTests(PostgresFixture postgres) : DatabaseTest(postgres)
{
    // Bytes được ghi trước khi metadata commit nên tệp mới nằm trong khoảng ân hạn; tua qua nó để tác vụ dọn được chạy.
    private static readonly TimeSpan PastGracePeriod = TimeSpan.FromHours(2);

    [Fact]
    public async Task UploadedFile_DownloadsByteForByte_WithTheTypeDetectedFromItsContent()
    {
        var owner = await Host.SignUpAsync();
        var noteId = await Host.CreateNoteAsync(owner);

        // Đuôi tệp và đường dẫn do trình duyệt gửi không được ảnh hưởng tới kiểu tệp hay tên lưu lại.
        var attachmentId = await UploadAsync(owner, noteId, Upload(@"C:\fakepath\photo.bin", Png));
        var download = await DownloadAsync(owner, attachmentId);

        Assert.Equal("photo.bin", download.Value.FileName);
        Assert.Equal("image/png", download.Value.MimeType);
        Assert.Equal(Png, await ReadAllAsync(download.Value.Content));
    }

    [Fact]
    public async Task BatchWithAnExecutable_IsRejectedAsAWhole_AndLeavesNoBytesBehind()
    {
        var owner = await Host.SignUpAsync();
        var noteId = await Host.CreateNoteAsync(owner);
        Host.ActAs(owner);

        var result = await Host.RunAsync((UploadAttachmentsCommand upload) => upload.ExecuteAsync(
            noteId,
            new UploadAttachmentsInputDto([Upload("ok.png", Png), Upload("invoice.pdf", WindowsExecutable)]),
            Ct));

        Assert.Equal(FileErrors.UnsupportedMediaType.Code, result.Error.Code);
        Assert.Empty((await Host.RunAsync((ListAttachmentsQuery list) => list.ExecuteAsync(noteId, Ct))).Value.Items);
        Assert.Empty(StoredFiles());
    }

    [Fact]
    public async Task ReadOnlyRecipient_CanDownload_ButCannotUploadOrRemove()
    {
        var owner = await Host.SignUpAsync();
        var reader = await Host.SignUpAsync();
        var noteId = await Host.CreateNoteAsync(owner);
        var attachmentId = await UploadAsync(owner, noteId, Upload("a.png", Png));
        await Host.ShareAsync(owner, noteId, reader, SharePermission.ReadOnly);

        Host.ActAs(reader);
        var download = await DownloadAsync(reader, attachmentId);
        var upload = await Host.RunAsync((UploadAttachmentsCommand command) =>
            command.ExecuteAsync(noteId, new UploadAttachmentsInputDto([Upload("b.png", Png)]), Ct));
        var remove = await Host.RunAsync((RemoveAttachmentCommand command) => command.ExecuteAsync(attachmentId, Ct));

        Assert.True(download.IsSuccess);
        await download.Value.Content.DisposeAsync();
        Assert.Equal(AccessErrors.Forbidden, upload.Error);
        Assert.Equal(AccessErrors.Forbidden, remove.Error);
    }

    // Gỡ tệp và xoá note chặn tải ngay trong transaction nghiệp vụ; bytes do tác vụ nền dọn sau, không đụng tệp còn sống.
    [Fact]
    public async Task RemovedAttachmentsAndDeletedNotes_StopDownloadingAtOnce_AndOnlyTheirBytesAreSwept()
    {
        var owner = await Host.SignUpAsync();
        var keptNote = await Host.CreateNoteAsync(owner);
        var deletedNote = await Host.CreateNoteAsync(owner);
        var removed = await UploadAsync(owner, keptNote, Upload("removed.png", Png));
        var kept = await UploadAsync(owner, keptNote, Upload("kept.png", Png));
        var ofDeletedNote = await UploadAsync(owner, deletedNote, Upload("gone.png", Png));

        Host.ActAs(owner);
        await Host.RunAsync((RemoveAttachmentCommand remove) => remove.ExecuteAsync(removed, Ct));
        await Host.RunAsync((DeleteNoteCommand delete) => delete.ExecuteAsync(deletedNote, Ct));

        Assert.Equal(NoteErrors.AttachmentNotFound, (await DownloadAsync(owner, removed)).Error);
        Assert.Equal(NoteErrors.AttachmentNotFound, (await DownloadAsync(owner, ofDeletedNote)).Error);

        Host.Clock.Advance(PastGracePeriod);
        await Host.RunJobOnceAsync<FileCleanupJobService>();

        Assert.Equal([await StorageKeyAsync(kept)], StoredFiles());
    }

    [Fact]
    public async Task ReplacingThenRemovingTheAvatar_ServesTheCurrentImage_AndSweepsTheOldBytes()
    {
        var user = await Host.SignUpAsync();
        Host.ActAs(user);

        await Host.RunAsync((UploadAvatarCommand upload) => upload.ExecuteAsync(Upload("first.png", Png), Ct));
        await Host.RunAsync((UploadAvatarCommand upload) => upload.ExecuteAsync(Upload("second.jpg", Jpeg), Ct));

        var avatar = await Host.RunAsync((GetAvatarQuery get) => get.ExecuteAsync(user.UserId, Ct));
        Assert.Equal("image/jpeg", avatar.Value.MimeType);
        Assert.Equal(Jpeg, await ReadAllAsync(avatar.Value.Content));

        Host.Clock.Advance(PastGracePeriod);
        await Host.RunJobOnceAsync<FileCleanupJobService>();
        Assert.Single(StoredFiles());

        await Host.RunAsync((RemoveAvatarCommand remove) => remove.ExecuteAsync(Ct));
        await Host.RunJobOnceAsync<FileCleanupJobService>();

        Assert.Equal(
            ProfileErrors.AvatarNotFound,
            (await Host.RunAsync((GetAvatarQuery get) => get.ExecuteAsync(user.UserId, Ct))).Error);
        Assert.Empty(StoredFiles());
    }

    private async Task<Guid> UploadAsync(TestAccount account, Guid noteId, FileUploadDto file)
    {
        Host.ActAs(account);
        var result = await Host.RunAsync((UploadAttachmentsCommand upload) =>
            upload.ExecuteAsync(noteId, new UploadAttachmentsInputDto([file]), Ct));

        return result.Value.Items.Single().AttachmentId;
    }

    private Task<Result<DownloadAttachmentOutputDto>> DownloadAsync(TestAccount account, Guid attachmentId)
    {
        Host.ActAs(account);
        return Host.RunAsync((DownloadAttachmentQuery download) => download.ExecuteAsync(attachmentId, Ct));
    }

    private Task<string> StorageKeyAsync(Guid attachmentId) =>
        Host.WithScopeAsync(services => services.GetRequiredService<AppDbContext>().Attachments
            .Where(a => a.Id == attachmentId)
            .Select(a => a.StorageKey)
            .SingleAsync(Ct));

    private List<string> StoredFiles() =>
        Directory.Exists(Host.StorageRoot)
            ? Directory.EnumerateFiles(Host.StorageRoot, "*", SearchOption.AllDirectories)
                .Select(path => Path.GetRelativePath(Host.StorageRoot, path).Replace(Path.DirectorySeparatorChar, '/'))
                .ToList()
            : [];

    private static async Task<byte[]> ReadAllAsync(Stream content)
    {
        await using (content)
        {
            using var buffer = new MemoryStream();
            await content.CopyToAsync(buffer, Ct);
            return buffer.ToArray();
        }
    }
}
