using Jotter.Domain;
using Microsoft.AspNetCore.Identity;
using NSubstitute;
using Xunit;

namespace Jotter.Application.UnitTests;

// LoginCommand tự tái hiện CheckPasswordSignInAsync(lockoutOnFailure: true), nên phải kiểm kỹ phần lockout.
public sealed class LoginCommandTests
{
    private const string Email = "an@jotter.app";

    private readonly User _user = TestData.NewUser(Email);
    private readonly UserManager<User> _userManager = TestData.NewUserManager();
    private readonly IUserRepository _users = Substitute.For<IUserRepository>();
    private readonly IUserSessionRepository _sessions = Substitute.For<IUserSessionRepository>();
    private readonly ITokenService _tokens = Substitute.For<ITokenService>();
    private readonly IUnitOfWork _unitOfWork = Substitute.For<IUnitOfWork>();

    public LoginCommandTests()
    {
        _users.GetByEmailAsync(Arg.Any<string>(), Arg.Any<CancellationToken>()).Returns((User?)null);
        _users.GetByEmailAsync(Email, Arg.Any<CancellationToken>()).Returns(_user);
        _tokens.IssueAccessToken(_user, Arg.Any<UserSession>()).Returns(new IssuedToken("jwt", TestData.Now.AddDays(30)));
    }

    [Fact]
    public async Task WrongPassword_CountsTheFailure_AndPersistsIt()
    {
        _userManager.IsLockedOutAsync(_user).Returns(false);
        _userManager.CheckPasswordAsync(_user, "sai").Returns(false);

        var result = await ExecuteAsync("sai");

        Assert.Equal(UserErrors.InvalidCredentials, result.Error);
        await _userManager.Received(1).AccessFailedAsync(_user);
        await _unitOfWork.Received(1).SaveChangesAsync(Arg.Any<CancellationToken>());
        _sessions.DidNotReceive().Add(Arg.Any<UserSession>());
    }

    [Fact]
    public async Task FailureThatReachesThreshold_ReportsLockout()
    {
        _userManager.IsLockedOutAsync(_user).Returns(false, true);
        _userManager.CheckPasswordAsync(_user, "sai").Returns(false);

        var result = await ExecuteAsync("sai");

        Assert.Equal(UserErrors.AccountLockedOut, result.Error);
    }

    // Đang bị khoá thì mật khẩu đúng cũng không được vào, và không được kiểm mật khẩu để tránh dò trong lúc khoá.
    [Fact]
    public async Task LockedOutAccount_IsRejectedEvenWithCorrectPassword()
    {
        _userManager.IsLockedOutAsync(_user).Returns(true);

        var result = await ExecuteAsync("dung");

        Assert.Equal(UserErrors.AccountLockedOut, result.Error);
        await _userManager.DidNotReceive().CheckPasswordAsync(Arg.Any<User>(), Arg.Any<string>());
        _sessions.DidNotReceive().Add(Arg.Any<UserSession>());
    }

    [Fact]
    public async Task UnknownEmail_GetsSameErrorAsWrongPassword()
    {
        var result = await new LoginCommand(_userManager, _users, _sessions, _tokens, _unitOfWork, new FixedClock(TestData.Now))
            .ExecuteAsync(new LoginInputDto("ai-do@jotter.app", "x"), TestData.Ct);

        Assert.Equal(UserErrors.InvalidCredentials, result.Error);
    }

    [Fact]
    public async Task CorrectPassword_StartsNewDeviceSession_AndIssuesTokenForIt()
    {
        _userManager.IsLockedOutAsync(_user).Returns(false);
        _userManager.CheckPasswordAsync(_user, "dung").Returns(true);

        var result = await ExecuteAsync("dung");

        Assert.Equal("jwt", result.Value.AccessToken);
        await _userManager.Received(1).ResetAccessFailedCountAsync(_user);
        _sessions.Received(1).Add(Arg.Is<UserSession>(s => s.UserId == _user.Id));
    }

    private Task<Result<LoginOutputDto>> ExecuteAsync(string password) =>
        new LoginCommand(_userManager, _users, _sessions, _tokens, _unitOfWork, new FixedClock(TestData.Now))
            .ExecuteAsync(new LoginInputDto(Email, password), TestData.Ct);
}
