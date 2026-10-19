using Jotter.Domain;

namespace Jotter.Application;

public sealed record ChangeSharePermissionInputDto(SharePermission Permission);

public sealed record ChangeSharePermissionOutputDto(Guid ShareId, SharePermission Permission, long ChangeSeq);
