namespace Jotter.Application;

public interface IFileTypeDetector
{
    // Chỉ dựa vào magic bytes, không tin tên tệp hay Content-Type client khai. Đọc xong phải trả stream về vị trí cũ.
    // Trả null khi nội dung không khớp chữ ký nào đã biết.
    Task<string?> DetectMimeTypeAsync(Stream content, CancellationToken ct);
}
