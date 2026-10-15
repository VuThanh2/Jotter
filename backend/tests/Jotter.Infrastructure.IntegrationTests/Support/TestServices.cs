using Jotter.Application;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Jotter.Infrastructure.IntegrationTests;

internal static class TestServices
{
    public const string JwtSecret = "integration-test-secret-integration-test-secret";

    public static IConfiguration Configuration(string connectionString, string storageRoot) =>
        new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:Default"] = connectionString,
                ["Jwt:Issuer"] = "jotter",
                ["Jwt:Audience"] = "jotter-app",
                ["Jwt:Secret"] = JwtSecret,
                ["Storage:RootPath"] = storageRoot
            })
            .Build();

    // Cùng cách Api đăng ký use case: quét mọi Command/Query của Application, mỗi request một instance.
    public static IServiceCollection AddApplicationUseCases(this IServiceCollection services)
    {
        var useCases = AssemblyReference.Assembly.GetTypes()
            .Where(type => type is { IsClass: true, IsAbstract: false }
                && (type.Name.EndsWith("Command", StringComparison.Ordinal)
                    || type.Name.EndsWith("Query", StringComparison.Ordinal)));

        foreach (var useCase in useCases)
        {
            services.AddScoped(useCase);
        }

        return services;
    }
}
