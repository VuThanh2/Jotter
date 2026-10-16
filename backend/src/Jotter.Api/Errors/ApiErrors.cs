using Jotter.Application;
using Jotter.Domain;

namespace Jotter.Api;

// Lỗi phát sinh ở tầng HTTP, trước khi request tới được use case. Mang mã ổn định như mọi lỗi nghiệp vụ để client switch.
public static class ApiErrors
{
    public static readonly Error ValidationError =
        Error.Validation("ValidationError", "Dữ liệu gửi lên không hợp lệ.");

    public static readonly Error InvalidIdempotencyKey =
        Error.Validation("InvalidIdempotencyKey", "Idempotency-Key phải là một UUID.");

    public static readonly Error BadRequest =
        Error.Validation("BadRequest", "Yêu cầu không hợp lệ.");

    public static readonly Error Unauthorized =
        Error.Unauthorized("Unauthorized", "Phiên đăng nhập không hợp lệ hoặc đã hết hạn. Vui lòng đăng nhập lại.");

    public static readonly Error EndpointNotFound =
        Error.NotFound("NotFound", "Không tìm thấy đường dẫn được yêu cầu.");

    public static readonly Error TooManyRequests =
        Error.TooManyRequests("TooManyRequests", "Bạn thao tác quá nhanh. Vui lòng thử lại sau.");

    // Các lỗi dưới không có ErrorType tương ứng nên luôn được ghi kèm mã HTTP thực tế của response.
    public static readonly Error MethodNotAllowed =
        Error.Validation("MethodNotAllowed", "Phương thức HTTP không được hỗ trợ cho đường dẫn này.");

    public static readonly Error PayloadTooLarge =
        Error.Validation("PayloadTooLarge", "Dữ liệu gửi lên vượt quá dung lượng cho phép.");

    public static readonly Error UnsupportedContentType =
        Error.Validation("UnsupportedContentType", "Định dạng nội dung của yêu cầu không được hỗ trợ.");

    public static readonly Error InternalError =
        Error.Unavailable("InternalError", "Đã có lỗi xảy ra phía máy chủ. Vui lòng thử lại sau.");

    public static Error Validation(IReadOnlyDictionary<string, FieldError[]> errors) =>
        ValidationError.WithDetails("errors", errors);

    public static Error ForStatusCode(int statusCode) => statusCode switch
    {
        StatusCodes.Status401Unauthorized => Unauthorized,
        StatusCodes.Status403Forbidden => AccessErrors.Forbidden,
        StatusCodes.Status404NotFound => EndpointNotFound,
        StatusCodes.Status405MethodNotAllowed => MethodNotAllowed,
        StatusCodes.Status413PayloadTooLarge => PayloadTooLarge,
        StatusCodes.Status415UnsupportedMediaType => UnsupportedContentType,
        StatusCodes.Status429TooManyRequests => TooManyRequests,
        >= StatusCodes.Status500InternalServerError => InternalError,
        _ => BadRequest
    };
}
