using FluentValidation;
using Jotter.Application;
using Jotter.Domain;
using Microsoft.AspNetCore.Mvc;

namespace Jotter.Api;

[ApiController]
[Route("api")]
public sealed class AttachmentsController : ControllerBase
{
    // Trần cứng chống request khổng lồ; giới hạn từng tệp (FileTooLarge kèm tên tệp) do use case kiểm.
    private const long MultipartOverheadBytes = 1024 * 1024;
    private const long MaxUploadRequestBytes =
        UploadAttachmentsValidator.MaxFilesPerRequest * Attachment.MaxSizeBytes + MultipartOverheadBytes;

    [HttpGet("notes/{noteId:guid}/attachments")]
    [ProducesResponseType<ListAttachmentsOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> List(Guid noteId, [FromServices] ListAttachmentsQuery query, CancellationToken ct)
    {
        var result = await query.ExecuteAsync(noteId, ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }

    // Không gắn [FromForm] cho tham số tệp: nó đổi nguồn bind từ FormFile sang Form, khiến OpenAPI mô tả body là
    // form-urlencoded và Swagger UI mất ô chọn tệp. [ApiController] tự suy ra FormFile, bind theo tên y như cũ.
    [HttpPost("notes/{noteId:guid}/attachments")]
    [Idempotent]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(MaxUploadRequestBytes)]
    [ProducesResponseType<UploadAttachmentsOutputDto>(StatusCodes.Status201Created)]
    public async Task<IActionResult> Upload(
        Guid noteId,
        IFormFileCollection files,
        [FromServices] IValidator<UploadAttachmentsInputDto> validator,
        [FromServices] UploadAttachmentsCommand command,
        CancellationToken ct)
    {
        // InputDto chỉ dựng được sau khi bind multipart nên ValidationFilter không thấy nó; kiểm tường minh ở đây.
        var input = new UploadAttachmentsInputDto(files.ToFileUploadDtos(Response));
        var validation = await validator.ValidateAsync(input, ct);
        if (!validation.IsValid)
        {
            return validation.Errors.ToError().ToActionResult();
        }

        var result = await command.ExecuteAsync(noteId, input, ct);
        return result.ToActionResult(StatusCodes.Status201Created);
    }

    // Quyền kiểm theo note chủ quản ngay trong mỗi lần tải — ưu điểm của Volume so với presigned URL.
    [HttpGet("attachments/{attachmentId:guid}/content")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> Download(
        Guid attachmentId,
        [FromServices] DownloadAttachmentQuery query,
        CancellationToken ct)
    {
        var result = await query.ExecuteAsync(attachmentId, ct);
        return result.ToActionResult(file =>
            File(file.Content, file.MimeType, file.FileName, enableRangeProcessing: true));
    }

    [HttpDelete("attachments/{attachmentId:guid}")]
    [Idempotent]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Remove(
        Guid attachmentId,
        [FromServices] RemoveAttachmentCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(attachmentId, ct);
        return result.ToActionResult(StatusCodes.Status204NoContent);
    }
}
