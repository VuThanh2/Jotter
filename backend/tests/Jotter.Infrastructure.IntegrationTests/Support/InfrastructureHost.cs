using System.Reflection;
using Jotter.Application;
using Jotter.Domain;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
using Microsoft.IdentityModel.JsonWebTokens;
using static Jotter.Infrastructure.IntegrationTests.TestData;

namespace Jotter.Infrastructure.IntegrationTests;

// Dựng đúng AddInfrastructure + các use case của Application trên một database riêng. Chỉ ba thứ được thay:
// người gọi (thay HttpContext), email (để đọc lại mã OTP) và đồng hồ (để tua thời gian).
internal sealed class InfrastructureHost : IAsyncDisposable
{
    public InfrastructureHost(string connectionString)
    {
        StorageRoot = Path.Combine(Path.GetTempPath(), "jotter-tests", Guid.NewGuid().ToString("N"));

        var configuration = TestServices.Configuration(connectionString, StorageRoot);

        // IConfiguration có sẵn trong DI như ở web host thật: options được bind từ đó.
        var services = new ServiceCollection();
        services.AddSingleton(configuration);
        services.AddLogging();
        services.AddSingleton<TimeProvider>(Clock);
        services.AddInfrastructure(configuration);
        services.AddApplicationUseCases();
        services.Replace(ServiceDescriptor.Singleton<ICurrentUser>(CurrentUser));
        services.Replace(ServiceDescriptor.Singleton<IEmailSender>(Emails));

        Services = services.BuildServiceProvider(new ServiceProviderOptions { ValidateScopes = true });
    }

    public ServiceProvider Services { get; }

    public MutableClock Clock { get; } = new();

    public TestCurrentUser CurrentUser { get; } = new();

    public CapturingEmailSender Emails { get; } = new();

    public string StorageRoot { get; }

    public static async Task<InfrastructureHost> CreateAsync(PostgresFixture postgres) =>
        new(await postgres.CreateDatabaseAsync());

    // Mỗi lần gọi một scope mới, như một request riêng: không có change tracker nào bị dùng chung giữa các bước.
    public async Task<T> WithScopeAsync<T>(Func<IServiceProvider, Task<T>> action)
    {
        await using var scope = Services.CreateAsyncScope();
        return await action(scope.ServiceProvider);
    }

    public async Task WithScopeAsync(Func<IServiceProvider, Task> action)
    {
        await using var scope = Services.CreateAsyncScope();
        await action(scope.ServiceProvider);
    }

    public Task<TResult> RunAsync<TUseCase, TResult>(Func<TUseCase, Task<TResult>> execute)
        where TUseCase : notnull =>
        WithScopeAsync(services => execute(services.GetRequiredService<TUseCase>()));

    public void ActAs(TestAccount account) => CurrentUser.Set(account.UserId, account.SessionId);

    public async Task<TestAccount> SignUpAsync(string displayName = "Người dùng")
    {
        var email = $"{Guid.NewGuid():N}@jotter.test";
        var result = await RunAsync((RegisterCommand register) =>
            register.ExecuteAsync(new RegisterInputDto(email, displayName, Password, Password), Ct));

        return TestAccount.FromToken(email, result.Value.AccessToken);
    }

    public async Task<TestAccount> SignInAsync(string email, string password = Password)
    {
        var result = await RunAsync((LoginCommand login) => login.ExecuteAsync(new LoginInputDto(email, password), Ct));
        return TestAccount.FromToken(email, result.Value.AccessToken);
    }

    public async Task<Guid> CreateNoteAsync(TestAccount owner, string title = "Tiêu đề", string content = "Nội dung")
    {
        ActAs(owner);
        var noteId = Guid.CreateVersion7();
        var result = await RunAsync((CreateNoteCommand create) =>
            create.ExecuteAsync(new CreateNoteInputDto(noteId, title, content, ConflictOfNoteId: null), Ct));

        return result.Value.NoteId;
    }

    public async Task<Guid> ShareAsync(TestAccount owner, Guid noteId, TestAccount recipient, SharePermission permission)
    {
        ActAs(owner);
        var result = await RunAsync((ShareNoteCommand share) =>
            share.ExecuteAsync(noteId, new ShareNoteInputDto([new ShareRecipientDto(recipient.Email, permission)]), Ct));

        return result.Value.Created.Single().ShareId;
    }

    public async Task ProtectAndLockAsync(TestAccount owner, Guid noteId, string password)
    {
        ActAs(owner);
        var result = await RunAsync((EnableProtectionCommand protect) =>
            protect.ExecuteAsync(noteId, new EnableProtectionInputDto(password, password), Ct));

        if (result.IsFailure)
        {
            throw new InvalidOperationException(result.Error.Code);
        }
    }

    // Đúng phép kiểm mà JwtBearer chạy ở mỗi request: lấy claim từ token rồi đối chiếu phiên và stamp trong DB.
    public Task<bool> IsSignedInAsync(string accessToken)
    {
        var token = new JsonWebToken(accessToken);
        return WithScopeAsync(services => services.GetRequiredService<SessionValidator>().IsActiveAsync(
            Guid.Parse(token.GetClaim(JotterClaimTypes.UserId).Value),
            Guid.Parse(token.GetClaim(JotterClaimTypes.SessionId).Value),
            token.GetClaim(JotterClaimTypes.SecurityStamp).Value,
            Ct));
    }

    // Tác vụ nền không được khởi động trong test; gọi thẳng một nhịp chạy để kết quả là tất định.
    public Task RunJobOnceAsync<TJob>()
        where TJob : PeriodicJobService
    {
        var job = Services.GetServices<IHostedService>().OfType<TJob>().Single();
        var runOnce = typeof(TJob).GetMethod("RunOnceAsync", BindingFlags.Instance | BindingFlags.NonPublic)
            ?? throw new InvalidOperationException($"{typeof(TJob).Name} không còn RunOnceAsync; cập nhật lại helper.");
        return (Task)runOnce.Invoke(job, [Ct])!;
    }

    public async ValueTask DisposeAsync()
    {
        await Services.DisposeAsync();

        if (Directory.Exists(StorageRoot))
        {
            Directory.Delete(StorageRoot, recursive: true);
        }
    }
}
