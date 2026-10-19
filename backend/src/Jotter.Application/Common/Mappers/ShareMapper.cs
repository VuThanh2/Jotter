using Jotter.Domain;

namespace Jotter.Application;

public static class ShareMapper
{
    public static SharedRecipientDto ToSharedRecipientDto(ShareGrant grant, string recipientEmail) =>
        new(grant.Id, grant.RecipientUserId, recipientEmail, grant.Permission, grant.SharedAt, grant.ChangeSeq);

    public static ChangeSharePermissionOutputDto ToChangeSharePermissionOutputDto(ShareGrant grant) =>
        new(grant.Id, grant.Permission, grant.ChangeSeq);
}
