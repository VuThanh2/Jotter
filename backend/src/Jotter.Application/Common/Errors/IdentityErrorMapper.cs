using Jotter.Domain;
using Microsoft.AspNetCore.Identity;

namespace Jotter.Application;

// Độ phức tạp mật khẩu chỉ có một nguồn sự thật là PasswordValidator của Identity; ở đây chỉ dịch kết quả của nó.
public static class IdentityErrorMapper
{
    private static readonly HashSet<string> DuplicateEmailCodes =
    [
        nameof(IdentityErrorDescriber.DuplicateEmail),
        nameof(IdentityErrorDescriber.DuplicateUserName)
    ];

    private static readonly HashSet<string> PasswordPolicyCodes =
    [
        nameof(IdentityErrorDescriber.PasswordTooShort),
        nameof(IdentityErrorDescriber.PasswordRequiresUniqueChars),
        nameof(IdentityErrorDescriber.PasswordRequiresNonAlphanumeric),
        nameof(IdentityErrorDescriber.PasswordRequiresDigit),
        nameof(IdentityErrorDescriber.PasswordRequiresLower),
        nameof(IdentityErrorDescriber.PasswordRequiresUpper)
    ];

    public static Error ToError(IdentityResult result)
    {
        if (result.Succeeded)
        {
            throw new ArgumentException("IdentityResult thành công không mang lỗi.", nameof(result));
        }

        // UserName = email nên Identity trả cùng lúc DuplicateUserName và DuplicateEmail.
        if (result.Errors.Any(e => DuplicateEmailCodes.Contains(e.Code)))
        {
            return UserErrors.EmailAlreadyExists;
        }

        if (result.Errors.Any(e => e.Code == nameof(IdentityErrorDescriber.PasswordMismatch)))
        {
            return UserErrors.InvalidCurrentPassword;
        }

        // Trả từng điều kiện chưa đạt để client hiện lỗi rõ ràng thay vì một thông báo chung chung.
        var unmetRequirements = result.Errors
            .Where(e => PasswordPolicyCodes.Contains(e.Code))
            .Select(e => new PasswordRequirementDto(e.Code, e.Description))
            .ToList();

        if (unmetRequirements.Count > 0)
        {
            return UserErrors.PasswordTooWeak.WithDetails("requirements", unmetRequirements);
        }

        return Error.Validation("ValidationError", string.Join(" ", result.Errors.Select(e => e.Description)));
    }
}
