using Jotter.Domain;

namespace Jotter.Application;

public sealed record ListSharesOutputDto(IReadOnlyList<ListSharesItemDto> Items);

public sealed record ListSharesItemDto(
    Guid ShareId,
    Guid RecipientUserId,
    string RecipientEmail,
    string RecipientDisplayName,
    SharePermission Permission,
    DateTimeOffset SharedAt);
