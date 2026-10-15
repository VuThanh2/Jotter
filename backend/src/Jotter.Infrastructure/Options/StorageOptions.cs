using System.ComponentModel.DataAnnotations;

namespace Jotter.Infrastructure;

public sealed class StorageOptions
{
    public const string SectionName = "Storage";

    [Required]
    public string RootPath { get; init; } = string.Empty;

    public TimeSpan CleanupInterval { get; init; } = TimeSpan.FromHours(1);

    // Bytes được ghi trước khi metadata commit, nên tệp mới hơn ngưỡng này chưa được coi là mồ côi.
    public TimeSpan OrphanGracePeriod { get; init; } = TimeSpan.FromHours(1);
}
