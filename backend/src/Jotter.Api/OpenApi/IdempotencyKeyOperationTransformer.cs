using Microsoft.AspNetCore.OpenApi;
using Microsoft.OpenApi;

namespace Jotter.Api;

// Header nằm ngoài chữ ký action (filter đọc trực tiếp) nên phải tự khai báo cho các thao tác gắn [Idempotent].
public sealed class IdempotencyKeyOperationTransformer : IOpenApiOperationTransformer
{
    public Task TransformAsync(OpenApiOperation operation, OpenApiOperationTransformerContext context, CancellationToken ct)
    {
        if (!context.Description.ActionDescriptor.EndpointMetadata.OfType<IdempotentAttribute>().Any())
        {
            return Task.CompletedTask;
        }

        operation.Parameters ??= [];
        operation.Parameters.Add(new OpenApiParameter
        {
            Name = IdempotencyFilter.KeyHeader,
            In = ParameterLocation.Header,
            Required = false,
            Description = "opId của operation trong outbox. Gửi lại cùng giá trị thì nhận lại đúng response lần đầu.",
            Schema = new OpenApiSchema { Type = JsonSchemaType.String, Format = "uuid" }
        });

        return Task.CompletedTask;
    }
}
