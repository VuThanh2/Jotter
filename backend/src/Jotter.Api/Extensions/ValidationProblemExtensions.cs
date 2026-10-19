using System.Text.Json;
using FluentValidation.Results;
using Jotter.Domain;
using Microsoft.AspNetCore.Mvc.ModelBinding;

namespace Jotter.Api;

// Gom lỗi theo từng trường (camelCase, khớp tên trường JSON) để Flutter hiện ngay dưới đúng ô nhập.
public static class ValidationProblemExtensions
{
    private static readonly FieldError InvalidValue =
        new("InvalidValue", "Giá trị không hợp lệ hoặc sai định dạng.");

    public static Error ToError(this IEnumerable<ValidationFailure> failures) =>
        ApiErrors.Validation(failures
            .GroupBy(failure => ToFieldName(failure.PropertyName))
            .ToDictionary(
                group => group.Key,
                group => group.Select(failure => new FieldError(failure.ErrorCode, failure.ErrorMessage)).ToArray()));

    // Lỗi model binding (JSON sai cú pháp, sai kiểu, enum lạ) không mang mã riêng, còn thông điệp gốc lộ tên kiểu
    // nội bộ, nên thay bằng một lỗi chung cho đúng trường bị hỏng.
    public static Error ToError(this ModelStateDictionary modelState) =>
        ApiErrors.Validation(modelState
            .Where(entry => entry.Value is { Errors.Count: > 0 })
            .GroupBy(entry => ToFieldName(entry.Key))
            .ToDictionary(group => group.Key, _ => new[] { InvalidValue }));

    // "Recipients[0].Email" → "recipients[0].email"; "$.themeMode" (đường dẫn JSON) → "themeMode".
    private static string ToFieldName(string path) =>
        string.Join('.', path
            .TrimStart('$')
            .Split('.', StringSplitOptions.RemoveEmptyEntries)
            .Select(JsonNamingPolicy.CamelCase.ConvertName));
}
