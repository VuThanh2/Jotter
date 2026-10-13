using FluentValidation;

namespace Jotter.Application;

// Bắt buộc nhập hai lần — chỉ hỏi một lần bị đề xếp vào nhóm subpar.
public sealed class EnableProtectionValidator : AbstractValidator<EnableProtectionInputDto>
{
    public EnableProtectionValidator()
    {
        RuleFor(x => x.Password).ValidNotePassword();
        RuleFor(x => x.ConfirmPassword).Equal(x => x.Password).WithError(InputErrors.PasswordMismatch);
    }
}
