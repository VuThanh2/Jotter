using Jotter.Domain;

namespace Jotter.Infrastructure;

public sealed record PermissionChangedMessage(Guid NoteId, SharePermission Permission)
    : RealtimeMessage("permissionChanged");
