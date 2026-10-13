using FluentValidation;

namespace Jotter.Application;

// Loại và kích thước từng tệp kiểm ở Command vì phải đọc magic bytes từ stream.
public sealed class UploadAttachmentsValidator : AbstractValidator<UploadAttachmentsInputDto>
{
    public const int MaxFilesPerRequest = 10;

    public UploadAttachmentsValidator()
    {
        RuleFor(x => x.Files).NotEmpty().Must(files => files is null || files.Count <= MaxFilesPerRequest);
    }
}
