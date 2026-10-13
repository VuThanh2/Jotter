namespace Jotter.Application;

// Controller giữ quyền dispose Content sau khi stream xong cho client.
public sealed record GetAvatarOutputDto(Stream Content, string MimeType);
