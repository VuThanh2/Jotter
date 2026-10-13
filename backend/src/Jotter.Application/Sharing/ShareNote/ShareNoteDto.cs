using Jotter.Domain;

namespace Jotter.Application;

public sealed record ShareNoteInputDto(IReadOnlyList<ShareRecipientDto> Recipients);

public sealed record ShareRecipientDto(string Email, SharePermission Permission);

// Xử lý theo từng người nhận để một email gõ sai không làm hỏng cả lô.
public sealed record ShareNoteOutputDto(IReadOnlyList<SharedRecipientDto> Created, IReadOnlyList<RejectedRecipientDto> Rejected);

public sealed record SharedRecipientDto(
    Guid ShareId,
    Guid RecipientUserId,
    string RecipientEmail,
    SharePermission Permission,
    DateTimeOffset SharedAt,
    long ChangeSeq);

public sealed record RejectedRecipientDto(string Email, string Code);
