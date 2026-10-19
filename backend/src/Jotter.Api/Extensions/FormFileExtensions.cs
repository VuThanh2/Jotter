using Jotter.Application;

namespace Jotter.Api;

public static class FormFileExtensions
{
    // Stream được gắn vào vòng đời response nên luôn được đóng, kể cả khi use case trả lỗi giữa chừng.
    // Body multipart đã được buffer nên stream seek được — điều kiện để đọc magic bytes rồi đọc lại từ đầu.
    public static FileUploadDto ToFileUploadDto(this IFormFile file, HttpResponse response)
    {
        var content = file.OpenReadStream();
        response.RegisterForDispose(content);

        return new FileUploadDto(file.FileName, file.Length, content);
    }

    public static IReadOnlyList<FileUploadDto> ToFileUploadDtos(this IFormFileCollection files, HttpResponse response) =>
        files.Select(file => file.ToFileUploadDto(response)).ToList();
}
