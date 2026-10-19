using Jotter.Application;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Jotter.Infrastructure;

// UC-33: lập chỉ mục ngữ nghĩa ở nền nên không làm chậm thao tác lưu note; lỗi thì lần chạy sau tự nhặt lại.
public sealed class EmbeddingIndexerJobService(
    IServiceScopeFactory scopeFactory,
    IOptions<LlmOptions> options,
    ILogger<EmbeddingIndexerJobService> logger) : PeriodicJobService(logger)
{
    private readonly LlmOptions _options = options.Value;

    protected override TimeSpan Interval => _options.IndexingInterval;

    protected override async Task RunOnceAsync(CancellationToken ct)
    {
        if (!_options.IsConfigured)
        {
            return;
        }

        // Mỗi lô một scope (một DbContext) để change tracker không phình ra khi phải xử lý nhiều lô liên tiếp.
        int processed;
        do
        {
            await using var scope = scopeFactory.CreateAsyncScope();
            var command = scope.ServiceProvider.GetRequiredService<IndexStaleNotesCommand>();

            var result = await command.ExecuteAsync(ct);
            if (result.IsFailure)
            {
                logger.LogWarning("Lập chỉ mục ngữ nghĩa tạm dừng: {Code}.", result.Error.Code);
                return;
            }

            processed = result.Value;
        }
        while (processed == IndexStaleNotesCommand.BatchSize);
    }

    public override Task StartAsync(CancellationToken cancellationToken)
    {
        if (!_options.IsConfigured)
        {
            logger.LogWarning(
                "Chưa cấu hình Llm:ApiKey — tính năng hỏi đáp AI sẽ không có dữ liệu để truy hồi.");
        }

        return base.StartAsync(cancellationToken);
    }
}
