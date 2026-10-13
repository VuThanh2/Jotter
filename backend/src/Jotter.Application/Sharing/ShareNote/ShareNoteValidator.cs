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

        RuleForEach(x => x.Recipients).ChildRules(recipient =>
        {
            recipient.RuleFor(x => x.Email).ValidEmail();
            recipient.RuleFor(x => x.Permission).IsInEnum().WithError(ShareErrors.InvalidPermission);
        });
    }
}
