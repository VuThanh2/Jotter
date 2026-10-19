namespace Jotter.Api;

public static class SwaggerExtensions
{
    private const string DocumentName = "v1";

    public static IServiceCollection AddApiDocumentation(this IServiceCollection services) =>
        services.AddOpenApi(DocumentName, options =>
        {
            options.AddDocumentTransformer((document, _, _) =>
            {
                document.Info.Title = "Jotter API";
                document.Info.Version = DocumentName;
                return Task.CompletedTask;
            });
            options.AddDocumentTransformer<BearerSecuritySchemeTransformer>();
            options.AddOperationTransformer<IdempotencyKeyOperationTransformer>();
        });

    // Chỉ mở ở Development: tài liệu mô tả toàn bộ bề mặt API, không cần phơi ra môi trường public.
    // Swagger UI là middleware nên phải đứng trước UseAuthorization, nếu không fallback policy sẽ đòi đăng nhập.
    public static WebApplication UseApiDocumentation(this WebApplication app)
    {
        if (!app.Environment.IsDevelopment())
        {
            return app;
        }

        app.MapOpenApi().AllowAnonymous();
        app.UseSwaggerUI(options =>
        {
            options.SwaggerEndpoint($"/openapi/{DocumentName}.json", "Jotter API");
            options.EnablePersistAuthorization();
        });

        return app;
    }
}
