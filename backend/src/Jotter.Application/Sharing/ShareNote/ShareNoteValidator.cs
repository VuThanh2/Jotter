using FluentValidation;
using Jotter.Domain;

namespace Jotter.Application;

public sealed class ShareNoteValidator : AbstractValidator<ShareNoteInputDto>
{
    public const int MaxRecipientsPerRequest = 20;

    public ShareNoteValidator()
    {
        RuleFor(x => x.Recipients)
            .NotEmpty()
            .Must(recipients => recipients is null || recipients.Count <= MaxRecipientsPerRequest);

        // Cố ý không kiểm định dạng email: email gõ sai phải bị từ chối riêng (RecipientNotRegistered)
        // chứ không được làm cả lô thất bại.
        RuleForEach(x => x.Recipients).ChildRules(recipient =>
        {
            recipient.RuleFor(x => x.Email).NotEmpty().MaximumLength(ValidationExtensions.MaxEmailLength);
            recipient.RuleFor(x => x.Permission).IsInEnum().WithError(ShareErrors.InvalidPermission);
        });
    }
}
