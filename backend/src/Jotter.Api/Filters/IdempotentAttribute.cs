using Microsoft.AspNetCore.Mvc;

namespace Jotter.Api;

// Gắn cho thao tác ghi dữ liệu note: outbox gửi lại cùng Idempotency-Key thì nhận lại đúng response lần đầu.
[AttributeUsage(AttributeTargets.Method)]
public sealed class IdempotentAttribute() : TypeFilterAttribute(typeof(IdempotencyFilter));
