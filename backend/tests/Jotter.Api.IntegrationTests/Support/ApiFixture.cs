using Jotter.Api.IntegrationTests;
using Jotter.Application;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Testcontainers.PostgreSql;
using Xunit;

[assembly: AssemblyFixture(typeof(ApiFixture))]

namespace Jotter.Api.IntegrationTests;

// Chạy đúng Program.cs của Api (cùng DI, cùng thứ tự middleware, cùng migration lúc khởi động) trên Postgres thật.
// Một host cho cả assembly; mỗi test tự đăng ký tài khoản riêng nên chạy song song không thấy dữ liệu của nhau.
public sealed class ApiFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder("postgres:17-alpine").Build();

    private readonly string _storageRoot =
        Path.Combine(Path.GetTempPath(), "jotter-api-tests", Guid.NewGuid().ToString("N"));

    private WebApplicationFactory<Program>? _factory;

    public IServiceProvider Services => Factory.Services;

    private WebApplicationFactory<Program> Factory =>
        _factory ?? throw new InvalidOperationException("ApiFixture chưa được khởi tạo.");

    public async ValueTask InitializeAsync()
    {
        await _postgres.StartAsync();

        // Program đọc cấu hình ngay lúc đăng ký service, trước khi WebApplicationFactory kịp chèn cấu hình của nó,
        // nên cấu hình test đi qua biến môi trường — đúng đường mà Railway và docker compose dùng.
        Environment.SetEnvironmentVariable("ConnectionStrings__Default", _postgres.GetConnectionString());
        Environment.SetEnvironmentVariable("Jwt__Secret", "api-integration-test-secret-api-integration-test");
        Environment.SetEnvironmentVariable("Storage__RootPath", _storageRoot);

        // Mọi request của TestServer chung một "IP": nới hạn mức đăng nhập để các test đăng ký tài khoản không chặn nhau.
        Environment.SetEnvironmentVariable("RateLimit__Auth__PermitLimit", "10000");

        _factory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
            builder.ConfigureTestServices(services => services.AddSingleton<ILlmService, FakeLlmService>()));

        // Khởi động ngay để lỗi cấu hình hay migration lộ ra một lần ở đây, không rải rác trong từng test.
        _ = _factory.Server;
    }

    public HttpClient CreateClient() => Factory.CreateClient();

    public async ValueTask DisposeAsync()
    {
        if (_factory is not null)
        {
            await _factory.DisposeAsync();
        }

        await _postgres.DisposeAsync();

        if (Directory.Exists(_storageRoot))
        {
            Directory.Delete(_storageRoot, recursive: true);
        }
    }
}
