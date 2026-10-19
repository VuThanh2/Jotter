using Jotter.Domain;
using NSubstitute;
using Xunit;

namespace Jotter.Application.UnitTests;

public sealed class UploadAttachmentsCommandTests
{
    private readonly Guid _userId = Guid.CreateVersion7();
    private readonly ICurrentUser _currentUser = Substitute.For<ICurrentUser>();
    private readonly INoteAccessPolicy _accessPolicy = Substitute.For<INoteAccessPolicy>();
    private readonly INoteRepository _notes = Substitute.For<INoteRepository>();
    private readonly IFileTypeDetector _fileTypes = Substitute.For<IFileTypeDetector>();
    private readonly IFileStorage _storage = Substitute.For<IFileStorage>();
    private readonly IUnitOfWork _unitOfWork = Substitute.For<IUnitOfWork>();
    private readonly Note _note;

    public UploadAttachmentsCommandTests()
    {
        _currentUser.UserId.Returns(_userId);
        _note = TestData.NewNote(_userId);
        _accessPolicy.GetAccessAsync(_userId, _note.Id, Arg.Any<CancellationToken>())
            .Returns(TestData.Access(NoteAccessLevel.Owner));
        _notes.GetByIdAsync(_note.Id, Arg.Any<CancellationToken>()).Returns(_note);
    }

    // Phải tin magic bytes chứ không tin tên tệp: setup.exe đổi tên thành ảnh vẫn bị chặn.
    [Fact]
    public async Task ExecutableDetectedByMagicBytes_IsRejected_AndNothingIsStored()
    {
        var file = GivenFile("anh-dep.png", size: 1_000, detectedMimeType: "application/x-msdownload");

        var result = await ExecuteAsync(file);

        Assert.Equal(FileErrors.UnsupportedMediaType.Code, result.Error.Code);
        Assert.Equal("anh-dep.png", result.Error.Details!["fileName"]);
        await AssertNothingPersistedAsync();
    }

    // Cả lô cùng thành công hoặc cùng thất bại: tệp hỏng ở cuối lô không được để lại bytes mồ côi của tệp đầu.
    [Fact]
    public async Task InvalidFileLaterInBatch_PreventsStoringEarlierValidFiles()
    {
        var valid = GivenFile("a.png", size: 1_000, detectedMimeType: "image/png");
        var tooLarge = GivenFile("b.mp4", size: Attachment.MaxSizeBytes + 1, detectedMimeType: "video/mp4");

        var result = await ExecuteAsync(valid, tooLarge);

        Assert.Equal(FileErrors.FileTooLarge.Code, result.Error.Code);
        await AssertNothingPersistedAsync();
    }

    // Tệp tổng quát không có chữ ký nhận diện được vẫn đính kèm được, nhưng không bao giờ mang MIME do client khai.
    [Fact]
    public async Task UnrecognizedSignature_IsStoredAsOctetStream_ThenCommitted()
    {
        var file = GivenFile("ghi-chu.txt", size: 42, detectedMimeType: null);

        var result = await ExecuteAsync(file);

        var uploaded = Assert.Single(result.Value.Items);
        Assert.Equal("application/octet-stream", uploaded.MimeType);
        var attachment = Assert.Single(_note.Attachments);
        Received.InOrder(() =>
        {
            _ = _storage.SaveAsync(attachment.StorageKey, file.Content, Arg.Any<CancellationToken>());
            _ = _unitOfWork.SaveChangesAsync(Arg.Any<CancellationToken>());
        });
    }

    private FileUploadDto GivenFile(string name, long size, string? detectedMimeType)
    {
        var file = new FileUploadDto(name, size, new MemoryStream([1, 2, 3]));
        _fileTypes.DetectMimeTypeAsync(file.Content, Arg.Any<CancellationToken>()).Returns(detectedMimeType);
        return file;
    }

    private Task<Result<UploadAttachmentsOutputDto>> ExecuteAsync(params FileUploadDto[] files) =>
        new UploadAttachmentsCommand(
                _currentUser, _accessPolicy, _notes, _fileTypes, _storage, _unitOfWork, new FixedClock(TestData.Now))
            .ExecuteAsync(_note.Id, new UploadAttachmentsInputDto(files), TestData.Ct);

    private async Task AssertNothingPersistedAsync()
    {
        await _storage.DidNotReceive()
            .SaveAsync(Arg.Any<string>(), Arg.Any<Stream>(), Arg.Any<CancellationToken>());
        await _unitOfWork.DidNotReceive().SaveChangesAsync(Arg.Any<CancellationToken>());
    }
}
