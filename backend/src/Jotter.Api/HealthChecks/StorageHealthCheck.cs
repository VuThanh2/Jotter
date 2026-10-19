using Jotter.Application;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace Jotter.Api;

// Ghi rồi xoá một tệp thăm dò thật: volume chưa mount, hết chỗ hay chỉ đọc đều lộ ra ở đây,
// thay vì lúc người dùng tải tệp đính kèm. Exception được HealthCheckService đổi thành Unhealthy.
public sealed class StorageHealthCheck(IFileStorage storage) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken ct = default)
    {
        // Key riêng cho mỗi lần kiểm để các lần kiểm đồng thời không tranh nhau cùng một tệp tạm.
        var probeKey = $"health/{Guid.NewGuid():N}";

        using var probe = new MemoryStream([0x6A]);
        await storage.SaveAsync(probeKey, probe, ct);
        await storage.DeleteAsync(probeKey, ct);

        return HealthCheckResult.Healthy();
    }
}
