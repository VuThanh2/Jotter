using Jotter.Domain;
using Microsoft.AspNetCore.Identity;
using Xunit;

namespace Jotter.Application.UnitTests;

public sealed class IdentityErrorMapperTests
{
    // UserName = email nên Identity báo trùng hai lần; client chỉ được nhận đúng một mã.
    [Fact]
    public void DuplicateUserNameAndEmail_CollapseIntoEmailAlreadyExists()
    {
        var result = IdentityResult.Failed(Failure("DuplicateUserName"), Failure("DuplicateEmail"));

        Assert.Equal(UserErrors.EmailAlreadyExists, IdentityErrorMapper.ToError(result));
    }

    [Fact]
    public void PasswordPolicyFailures_ListEveryUnmetRequirement()
    {
        var result = IdentityResult.Failed(Failure("PasswordTooShort"), Failure("PasswordRequiresDigit"));

        var error = IdentityErrorMapper.ToError(result);

        Assert.Equal(UserErrors.PasswordTooWeak.Code, error.Code);
        var requirements = Assert.IsAssignableFrom<IEnumerable<PasswordRequirementDto>>(error.Details!["requirements"]);
        Assert.Equal(new[] { "PasswordTooShort", "PasswordRequiresDigit" }, requirements.Select(r => r.Code));
    }

    [Fact]
    public void IdentityPasswordMismatch_MeansWrongCurrentPassword()
    {
        var result = IdentityResult.Failed(Failure("PasswordMismatch"));

        Assert.Equal(UserErrors.InvalidCurrentPassword, IdentityErrorMapper.ToError(result));
    }

    private static IdentityError Failure(string code) => new() { Code = code, Description = code };
}
