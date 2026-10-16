using System.Collections.Concurrent;
using System.Reflection;
using FluentValidation;
using FluentValidation.Results;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc.ModelBinding;

namespace Jotter.Api;

// Chạy validator của mọi InputDto trước khi vào Command/Query, nên use case luôn nhận dữ liệu đúng hình dạng.
// Thiếu hẳn một tham số bắt buộc (body "null", thiếu tệp) cũng bị chặn ở đây thay vì thành NullReferenceException.
public sealed class ValidationFilter : IAsyncActionFilter
{
    private static readonly ConcurrentDictionary<ParameterInfo, bool> RequiredParameters = new();

    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var failures = new List<ValidationFailure>();

        foreach (var parameter in context.ActionDescriptor.Parameters.OfType<ControllerParameterDescriptor>())
        {
            if (!IsBoundFromRequest(parameter))
            {
                continue;
            }

            context.ActionArguments.TryGetValue(parameter.Name, out var argument);
            if (argument is null)
            {
                if (IsRequired(parameter.ParameterInfo))
                {
                    failures.Add(new ValidationFailure(FieldNameOf(parameter), "Thiếu dữ liệu bắt buộc.")
                    {
                        ErrorCode = "Required"
                    });
                }

                continue;
            }

            var validatorType = typeof(IValidator<>).MakeGenericType(parameter.ParameterType);
            if (context.HttpContext.RequestServices.GetService(validatorType) is IValidator validator)
            {
                var result = await validator.ValidateAsync(
                    new ValidationContext<object>(argument),
                    context.HttpContext.RequestAborted);

                failures.AddRange(result.Errors);
            }
        }

        if (failures.Count > 0)
        {
            context.Result = failures.ToError().ToActionResult();
            return;
        }

        await next();
    }

    private static bool IsBoundFromRequest(ControllerParameterDescriptor parameter) =>
        parameter.BindingInfo?.BindingSource is not { } source
        || (source != BindingSource.Services && source != BindingSource.Special);

    // Thiếu cả body thì lỗi thuộc về toàn bộ body (trường rỗng), giống lỗi model binding của MVC.
    private static string FieldNameOf(ControllerParameterDescriptor parameter) =>
        parameter.BindingInfo?.BindingSource == BindingSource.Body
            ? string.Empty
            : parameter.BindingInfo?.BinderModelName ?? parameter.Name;

    private static bool IsRequired(ParameterInfo parameter) =>
        RequiredParameters.GetOrAdd(parameter, static info =>
            !info.ParameterType.IsValueType
            && new NullabilityInfoContext().Create(info).WriteState == NullabilityState.NotNull);
}
