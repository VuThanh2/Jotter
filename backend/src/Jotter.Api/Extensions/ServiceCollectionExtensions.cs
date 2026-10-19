using System.Globalization;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.Unicode;
using FluentValidation;
using Jotter.Application;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.Extensions.Options;
using Microsoft.Net.Http.Headers;
using FrameworkCorsOptions = Microsoft.AspNetCore.Cors.Infrastructure.CorsOptions;

namespace Jotter.Api;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddPresentation(this IServiceCollection services, IConfiguration configuration)
    {
        services
            .AddApplicationUseCases()
            .AddControllersWithConventions()
            .AddCorsPolicy()
            .AddProxySupport()
            .AddApiRateLimiting()
            .AddApiDocumentation()
            .AddApiHealthChecks(configuration);

        return services;
    }

    // Controller inject thẳng Command/Query, không qua mediator. Mỗi request một instance.
    private static IServiceCollection AddApplicationUseCases(this IServiceCollection services)
    {
        foreach (var useCase in AssemblyReference.Assembly.GetTypes().Where(IsUseCase))
        {
            services.AddScoped(useCase);
        }

        services.AddValidatorsFromAssembly(AssemblyReference.Assembly);

        // Thông điệp mặc định của FluentValidation cùng ngôn ngữ với thông điệp nghiệp vụ.
        ValidatorOptions.Global.LanguageManager.Culture = CultureInfo.GetCultureInfo("vi");

        return services;
    }

    private static bool IsUseCase(Type type) =>
        type is { IsClass: true, IsAbstract: false, IsPublic: true }
        && (type.Name.EndsWith("Command", StringComparison.Ordinal) || type.Name.EndsWith("Query", StringComparison.Ordinal))
        && type.GetMethod("ExecuteAsync") is not null;

    private static IServiceCollection AddControllersWithConventions(this IServiceCollection services)
    {
        services
            .AddControllers(options =>
            {
                options.Filters.Add<ValidationFilter>();

                // "Bắt buộc" do validator kiểm, kèm mã lỗi riêng; để MVC tự sinh [Required] ngầm thì cùng một luật
                // có hai nguồn, hai thông điệp.
                options.SuppressImplicitRequiredAttributeForNonNullableReferenceTypes = true;
            })
            .AddJsonOptions(options =>
            {
                ConfigureJson(options.JsonSerializerOptions);
                options.AllowInputFormatterExceptionMessages = false;
            })
            .ConfigureApiBehaviorOptions(options =>
            {
                options.InvalidModelStateResponseFactory = context => context.ModelState.ToError().ToActionResult();

                // Lỗi rỗng của framework (415, 404...) để status code pages ghi bằng writer chung, thay vì ProblemDetails
                // mặc định của MVC không có "code".
                options.SuppressMapClientErrors = true;
            });

        // Serializer của Minimal API: luồng SSE và OpenAPI dùng nó, phải cho ra cùng hình dạng JSON với controller.
        services.ConfigureHttpJsonOptions(options => ConfigureJson(options.SerializerOptions));

        return services;
    }

    private static void ConfigureJson(JsonSerializerOptions options)
    {
        // Enum đi dạng chuỗi ("ReadOnly", "Dark") đúng như hợp đồng API; số nguyên bị từ chối thay vì âm thầm nhận giá trị lạ.
        options.Converters.Add(new JsonStringEnumConverter(namingPolicy: null, allowIntegerValues: false));

        // Mặc định mọi ký tự ngoài ASCII bị escape thành \uXXXX, làm nội dung note tiếng Việt phình gấp vài lần.
        // Vẫn escape các ký tự nhạy cảm với HTML như cấu hình mặc định.
        options.Encoder = JavaScriptEncoder.Create(UnicodeRanges.All);
    }

    private static IServiceCollection AddCorsPolicy(this IServiceCollection services)
    {
        services
            .AddOptions<CorsOptions>()
            .BindConfiguration(CorsOptions.SectionName)
            .ValidateDataAnnotations()
            .ValidateOnStart();

        services.AddCors();
        services
            .AddOptions<FrameworkCorsOptions>()
            .Configure<IOptions<CorsOptions>>((cors, allowed) => cors.AddDefaultPolicy(policy =>
            {
                if (allowed.Value.AllowsAnyOrigin)
                {
                    policy.AllowAnyOrigin();
                }
                else
                {
                    policy.WithOrigins(allowed.Value.AllowedOrigins);
                }

                policy
                    .AllowAnyHeader()
                    .AllowAnyMethod()
                    .WithExposedHeaders(IdempotencyFilter.ReplayHeader, HeaderNames.RetryAfter, HeaderNames.ContentDisposition)
                    .SetPreflightMaxAge(TimeSpan.FromMinutes(10));
            }));

        return services;
    }

    // Railway (và mọi reverse proxy) đứng trước container: không đọc X-Forwarded-For thì mọi request đều mang IP của
    // proxy và rate limit theo IP gộp tất cả người dùng làm một. Proxy của Railway không có IP cố định để khai báo trước,
    // nên chỉ tin đúng một hop gần nhất — giá trị client tự chèn thêm vào header nằm xa hơn và bị bỏ qua.
    private static IServiceCollection AddProxySupport(this IServiceCollection services) =>
        services.Configure<ForwardedHeadersOptions>(options =>
        {
            options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
            options.ForwardLimit = 1;
            options.KnownIPNetworks.Clear();
            options.KnownProxies.Clear();
        });
}
