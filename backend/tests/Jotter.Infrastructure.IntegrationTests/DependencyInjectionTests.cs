using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Jotter.Infrastructure.IntegrationTests;

public sealed class DependencyInjectionTests
{
    // Thiếu một đăng ký chỉ lộ ra khi đúng endpoint đó được gọi; ValidateOnBuild bắt nó ngay, cho mọi use case.
    [Fact]
    public void AddInfrastructure_SatisfiesEveryDependencyOfEveryApplicationUseCase()
    {
        var configuration = TestServices.Configuration("Host=localhost;Database=unused", "unused-storage-root");
        var services = new ServiceCollection();
        services.AddSingleton(configuration);
        services.AddLogging();
        services.AddRouting(); // Web host luôn có sẵn; authorization của ASP.NET Core cần nó.
        services.AddInfrastructure(configuration);
        services.AddApplicationUseCases();

        using var provider = services.BuildServiceProvider(
            new ServiceProviderOptions { ValidateOnBuild = true, ValidateScopes = true });
    }
}
