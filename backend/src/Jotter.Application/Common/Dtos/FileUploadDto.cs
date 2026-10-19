namespace Jotter.Application;

// Controller chuyển IFormFile sang DTO này và giữ quyền dispose stream; Content phải seek được để đọc magic bytes.
// SizeBytes là kích thước server đo được khi nhận multipart, không phải con số client khai.
public sealed record FileUploadDto(string FileName, long SizeBytes, Stream Content);
