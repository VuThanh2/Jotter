using Jotter.Domain;

namespace Jotter.Application;

public sealed class ShareNoteCommand(
    ICurrentUser currentUser,
    INoteAccessPolicy accessPolicy,
    INoteRepository notes,
    IUserRepository users,
    IShareGrantRepository shareGrants,
    IEmailSender emailSender,
    IUnitOfWork unitOfWork,
    TimeProvider clock)
{
    public async Task<Result<ShareNoteOutputDto>> ExecuteAsync(
        Guid noteId,
        ShareNoteInputDto input,
        CancellationToken ct)
    {
        // "Chỉ chủ sở hữu được cấp quyền" là bất biến xuyên Aggregate nên kiểm ở đây, trước khi gọi Domain.
        // Người được chia sẻ vì vậy không thể chia sẻ tiếp; note đang bảo vệ phải được mở khoá trước.
        var access = await accessPolicy.GetAccessAsync(currentUser.UserId, noteId, ct);
        var permission = access.EnsureUnlockedOwner();
        if (permission.IsFailure)
        {
            return permission.Error;
        }

        var note = await notes.GetByIdAsync(noteId, ct);
        if (note is null)
        {
            return NoteErrors.NotFound;
        }

        var owner = await users.GetByIdAsync(note.OwnerId, ct);
        if (owner is null)
        {
            return UserErrors.NotFound;
        }

        var now = clock.GetUtcNow();
        var granted = new List<GrantedRecipient>();
        var rejected = new List<(string Email, Error Error)>();

        // Xử lý theo từng người nhận để một email gõ sai không làm cả lô thất bại.
        foreach (var recipient in input.Recipients)
        {
            var grant = await GrantAsync(note, recipient, granted, now, ct);
            if (grant.IsSuccess)
            {
                granted.Add(grant.Value);
            }
            else
            {
                rejected.Add((recipient.Email, grant.Error));
            }
        }

        var rejectedDtos = rejected.Select(r => new RejectedRecipientDto(r.Email, r.Error.Code)).ToList();

        // Toàn bộ bị từ chối: trả lỗi của người đầu tiên để client switch được, kèm chi tiết từng email.
        if (granted.Count == 0)
        {
            return rejected[0].Error.WithDetails("rejected", rejectedDtos);
        }

        await unitOfWork.SaveChangesAsync(ct);

        // Thông báo không bao giờ kèm mật khẩu note — chủ sở hữu tự gửi qua kênh riêng.
        foreach (var (grant, recipient) in granted)
        {
            await emailSender.SendNoteSharedAsync(
                recipient.Email!,
                recipient.DisplayName,
                owner.DisplayName,
                note.Title,
                grant.Permission,
                ct);
        }

        var createdDtos = granted
            .Select(g => ShareMapper.ToSharedRecipientDto(g.Grant, g.Recipient.Email!))
            .ToList();

        return new ShareNoteOutputDto(createdDtos, rejectedDtos);
    }

    private async Task<Result<GrantedRecipient>> GrantAsync(
        Note note,
        ShareRecipientDto recipient,
        IReadOnlyCollection<GrantedRecipient> grantedInThisRequest,
        DateTimeOffset now,
        CancellationToken ct)
    {
        // Chỉ chia sẻ cho tài khoản đã đăng ký — cho nhập email bất kỳ là ví dụ subpar trong đề.
        var user = await users.GetByEmailAsync(recipient.Email, ct);
        if (user is null)
        {
            return ShareErrors.RecipientNotRegistered;
        }

        // Cùng một người có thể xuất hiện hai lần trong lô dưới hai cách viết hoa/thường khác nhau.
        var alreadyGranted = grantedInThisRequest.Any(g => g.Recipient.Id == user.Id)
            || await shareGrants.ExistsActiveAsync(note.Id, user.Id, ct);

        if (alreadyGranted)
        {
            return ShareErrors.DuplicateShare;
        }

        var created = ShareGrant.Create(note.Id, note.OwnerId, user.Id, recipient.Permission, now);
        if (created.IsFailure)
        {
            return created.Error;
        }

        shareGrants.Add(created.Value);

        return new GrantedRecipient(created.Value, user);
    }

    private sealed record GrantedRecipient(ShareGrant Grant, User Recipient);
}
