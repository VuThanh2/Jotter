using Microsoft.AspNetCore.DataProtection;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
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

    // Hosted service làm nóng key ring của DataProtection ghi key ra ~/.aspnet và sinh cảnh báo lúc khởi động, trong
    // khi ứng dụng không dùng key ring đó. Nó được nhận diện theo tên kiểu internal: framework đổi tên thì vế sau hỏng.
    [Fact]
    public void AddInfrastructure_DropsTheDataProtectionKeyRingWarmUp()
    {
        var authenticationOnly = new ServiceCollection();
        authenticationOnly.AddAuthentication();
        Assert.Contains(authenticationOnly, IsDataProtectionHostedService);

        var configuration = TestServices.Configuration("Host=localhost;Database=unused", "unused-storage-root");
        var services = new ServiceCollection();
        services.AddSingleton(configuration);
        services.AddInfrastructure(configuration);

        Assert.DoesNotContain(services, IsDataProtectionHostedService);
    }

    private static bool IsDataProtectionHostedService(ServiceDescriptor descriptor) =>
        descriptor.ServiceType == typeof(IHostedService)
        && descriptor.ImplementationType?.Assembly == typeof(DataProtectionOptions).Assembly;
}
