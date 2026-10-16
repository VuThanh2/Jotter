using System.Net.ServerSentEvents;
using System.Runtime.CompilerServices;
using Jotter.Domain;
using Microsoft.AspNetCore.Mvc;

namespace Jotter.Api;

// Result → IActionResult. Mã thành công do controller ghi tường minh theo trang API Endpoint;
// mã lỗi suy ra từ ErrorType.
public static class ResultExtensions
{
    public static IActionResult ToActionResult(this Result result, int successStatusCode) =>
        result.IsSuccess ? new StatusCodeResult(successStatusCode) : result.Error.ToActionResult();

    public static IActionResult ToActionResult<TValue>(this Result<TValue> result, int successStatusCode) =>
        result.ToActionResult(value => new ObjectResult(value) { StatusCode = successStatusCode });

    public static IActionResult ToActionResult<TValue>(
        this Result<TValue> result,
        Func<TValue, IActionResult> onSuccess) =>
        result.IsSuccess ? onSuccess(result.Value) : result.Error.ToActionResult();

    // Lỗi phát hiện trước khi stream bắt đầu vẫn là ProblemDetails với mã HTTP đúng nghĩa;
    // lỗi giữa chừng là việc của chính luồng sự kiện vì header đã được gửi đi.
    public static IActionResult ToServerSentEventsResult<TEvent>(
        this Result<IAsyncEnumerable<TEvent>> result,
        Func<TEvent, string> eventTypeOf)
        where TEvent : notnull =>
        result.ToActionResult(events =>
            new HttpResultAdapter(TypedResults.ServerSentEvents(ToSseItems(events, eventTypeOf))));

    public static IActionResult ToActionResult(this Error error) => new ProblemResult(error);

    // Kiểu dữ liệu khai báo là object để mỗi sự kiện được serialize theo kiểu thực tế của nó, không theo kiểu cơ sở.
    private static async IAsyncEnumerable<SseItem<object>> ToSseItems<TEvent>(
        IAsyncEnumerable<TEvent> events,
        Func<TEvent, string> eventTypeOf,
        [EnumeratorCancellation] CancellationToken ct = default)
        where TEvent : notnull
    {
        await foreach (var item in events.WithCancellation(ct))
        {
            yield return new SseItem<object>(item, eventTypeOf(item));
        }
    }

    private sealed class ProblemResult(Error error) : IActionResult
    {
        public Task ExecuteResultAsync(ActionContext context) => context.HttpContext.WriteProblemAsync(error);
    }

    private sealed class HttpResultAdapter(IResult result) : IActionResult
    {
        public Task ExecuteResultAsync(ActionContext context) => result.ExecuteAsync(context.HttpContext);
    }
}
