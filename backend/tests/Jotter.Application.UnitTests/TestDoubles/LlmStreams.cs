namespace Jotter.Application.UnitTests;

internal static class LlmStreams
{
    public static async IAsyncEnumerable<string> Of(params string[] deltas)
    {
        foreach (var delta in deltas)
        {
            await Task.Yield();
            yield return delta;
        }
    }

    public static async IAsyncEnumerable<string> FailingAfter(LlmFailureKind kind, params string[] deltas)
    {
        foreach (var delta in deltas)
        {
            await Task.Yield();
            yield return delta;
        }

        await Task.Yield();
        throw new LlmException(kind, "Provider lỗi.");
    }
}
