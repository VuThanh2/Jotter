using Jotter.Application;
using Jotter.Domain;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace Jotter.Infrastructure;

public static class InfrastructureExtensions
{
    private const string ConnectionStringName = "Default";

    // Kiểu internal của framework nên chỉ nhận diện được qua tên; DependencyInjectionTests báo ngay nếu tên này trôi.
    private const string DataProtectionHostedServiceName =
        "Microsoft.AspNetCore.DataProtection.Internal.DataProtectionHostedService";

    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.TryAddSingleton(TimeProvider.System);
        services.AddHttpContextAccessor();

        services
            .AddInfrastructureOptions()
            .AddPersistence(configuration)
            .AddIdentityAndAuthentication()
            .AddRepositories()
            .AddInfrastructureServices()
            .AddEmail()
            .AddRealtime()
            .AddAi()
            .AddBackgroundJobs();

        return services;
    }

    // Thiếu biến môi trường bắt buộc thì dừng ngay lúc khởi động thay vì lỗi ngầm lúc chạy.
    private static IServiceCollection AddInfrastructureOptions(this IServiceCollection services)
    {
        services.AddValidatedOptions<JwtOptions>(JwtOptions.SectionName);
        services.AddValidatedOptions<EmailOptions>(EmailOptions.SectionName);
        services.AddValidatedOptions<StorageOptions>(StorageOptions.SectionName);
        services.AddValidatedOptions<LlmOptions>(LlmOptions.SectionName);
        services.AddValidatedOptions<RetentionOptions>(RetentionOptions.SectionName);

        return services;
    }

    private static IServiceCollection AddPersistence(this IServiceCollection services, IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString(ConnectionStringName)
            ?? throw new InvalidOperationException($"Thiếu ConnectionStrings:{ConnectionStringName}.");

        services.AddScoped<ChangeSeqInterceptor>();
        services.AddDbContext<AppDbContext>((provider, options) =>
        {
            PersistenceSetup.Configure(options, connectionString);
            options.AddInterceptors(provider.GetRequiredService<ChangeSeqInterceptor>());
        });

        services.AddScoped<IUnitOfWork, UnitOfWork>();
        services.AddScoped<DemoDataSeeder>();

        return services;
    }

    private static IServiceCollection AddIdentityAndAuthentication(this IServiceCollection services)
    {
        services
            .AddIdentityCore<User>(options =>
            {
                options.User.RequireUniqueEmail = true;

                // Chưa kích hoạt vẫn đăng nhập và dùng được toàn bộ chức năng (UC-01, UC-02).
                options.SignIn.RequireConfirmedAccount = false;
                options.SignIn.RequireConfirmedEmail = false;

                options.Lockout.AllowedForNewUsers = true;
                options.Lockout.MaxFailedAccessAttempts = 5;
                options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(5);
            })
            .AddUserStore<AppUserStore>()
            .AddDefaultTokenProviders();

        // Token của DataProtectorTokenProvider được sinh và tiêu thụ ngay trong cùng một lần gọi (OTP của mình mới là
        // thứ người dùng nhập), nên khoá chỉ cần sống trong bộ nhớ: không ghi khoá ra filesystem tạm của container.
        services.AddSingleton<IDataProtectionProvider, EphemeralDataProtectionProvider>();

        services.AddScoped<SessionValidator>();
        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer();

        // AddAuthentication kéo theo AddDataProtection, và nó đăng ký một hosted service tạo sẵn key ring mặc định lúc
        // khởi động: ghi key không mã hoá ra ~/.aspnet trong container kèm hai cảnh báo. Không gì dùng key ring đó (JWT
        // ký bằng secret riêng, token Identity đi qua provider ephemeral ở trên) nên bỏ bước làm nóng này; nếu sau này
        // có thứ thật sự cần nó, key ring vẫn được tạo lúc dùng và cảnh báo sẽ hiện lại đúng lúc.
        var keyRingWarmUp = services.SingleOrDefault(descriptor =>
            descriptor.ServiceType == typeof(IHostedService)
            && descriptor.ImplementationType?.FullName == DataProtectionHostedServiceName);
        if (keyRingWarmUp is not null)
        {
            services.Remove(keyRingWarmUp);
        }
        services
            .AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
            .Configure<IOptions<JwtOptions>>((bearer, jwtOptions) => ConfigureJwtBearer(bearer, jwtOptions.Value));

        // REST mặc định yêu cầu đăng nhập (fallback) và từ chối token scope "ws"; endpoint công khai phải [AllowAnonymous].
        var restPolicy = new AuthorizationPolicyBuilder(JwtBearerDefaults.AuthenticationScheme)
            .RequireAuthenticatedUser()
            .AddRequirements(new RestScopeRequirement())
            .Build();

        services.AddSingleton<IAuthorizationHandler, RestScopeAuthorizationHandler>();
        services.AddAuthorizationBuilder()
            .SetDefaultPolicy(restPolicy)
            .SetFallbackPolicy(restPolicy)
            .AddPolicy(WebSocketHandler.AuthorizationPolicy, policy => policy
                .AddAuthenticationSchemes(JwtBearerDefaults.AuthenticationScheme)
                .RequireAuthenticatedUser()
                .RequireClaim(JotterClaimTypes.Scope, JotterClaimTypes.RealtimeScope));

        return services;
    }

    private static void ConfigureJwtBearer(JwtBearerOptions bearer, JwtOptions jwt)
    {
        // Giữ nguyên tên claim lúc phát hành để REST và WebSocket đọc userId theo cùng một cách.
        bearer.MapInboundClaims = false;

        bearer.TokenValidationParameters = new TokenValidationParameters
        {
            ValidIssuer = jwt.Issuer,
            ValidAudience = jwt.Audience,
            IssuerSigningKey = JwtTokenService.CreateSigningKey(jwt),
            ValidAlgorithms = [SecurityAlgorithms.HmacSha256],
            NameClaimType = JotterClaimTypes.UserId,
            // Token realtime chỉ sống vài phút, độ lệch đồng hồ mặc định 5 phút sẽ nhân đôi thời hạn đó.
            ClockSkew = TimeSpan.FromSeconds(30)
        };

        bearer.Events = new JwtBearerEvents
        {
            // Trình duyệt không gắn được header khi bắt tay WebSocket, nên chỉ riêng /ws nhận token qua query string.
            OnMessageReceived = context =>
            {
                if (context.Request.Path.StartsWithSegments(WebSocketHandler.Path)
                    && context.Request.Query["token"].FirstOrDefault() is { Length: > 0 } token)
                {
                    context.Token = token;
                }

                return Task.CompletedTask;
            },
            OnTokenValidated = context =>
                context.HttpContext.RequestServices.GetRequiredService<SessionValidator>().ValidateAsync(context)
        };
    }

    private static IServiceCollection AddRepositories(this IServiceCollection services)
    {
        services.AddScoped<IUserRepository, UserRepository>();
        services.AddScoped<IUserSessionRepository, UserSessionRepository>();
        services.AddScoped<IVerificationCodeRepository, VerificationCodeRepository>();
        services.AddScoped<IPasswordResetTicketRepository, PasswordResetTicketRepository>();
        services.AddScoped<INoteRepository, NoteRepository>();
        services.AddScoped<ILabelRepository, LabelRepository>();
        services.AddScoped<IShareGrantRepository, ShareGrantRepository>();
        services.AddScoped<INoteUnlockSessionRepository, NoteUnlockSessionRepository>();

        return services;
    }

    private static IServiceCollection AddInfrastructureServices(this IServiceCollection services)
    {
        services.AddScoped<ICurrentUser, CurrentUser>();
        services.AddSingleton<ITokenService, JwtTokenService>();
        services.AddSingleton<IOtpService, OtpService>();
        services.AddSingleton<INotePasswordHasher, NotePasswordHasher>();

        // Một instance cho cả interface lẫn kiểu cụ thể: QueryService dựng truy vấn trên đúng luật của policy.
        services.AddScoped<NoteAccessPolicy>();
        services.AddScoped<INoteAccessPolicy>(provider => provider.GetRequiredService<NoteAccessPolicy>());

        services.AddScoped<INoteQueryService, NoteQueryService>();
        services.AddScoped<ILabelQueryService, LabelQueryService>();
        services.AddScoped<IShareQueryService, ShareQueryService>();
        services.AddScoped<ISyncQueryService, SyncQueryService>();
        services.AddScoped<IEmbeddingStore, EmbeddingStore>();
        services.AddScoped<IIdempotencyStore, IdempotencyStore>();

        // Strategy: đổi sang R2 chỉ cần thay đúng chỗ này.
        services.AddSingleton<LocalVolumeFileStorage>();
        services.AddSingleton<IFileStorage>(provider => provider.GetRequiredService<LocalVolumeFileStorage>());
        services.AddSingleton<IFileInventory>(provider => provider.GetRequiredService<LocalVolumeFileStorage>());
        services.AddSingleton<IFileTypeDetector, MagicBytesFileTypeDetector>();

        return services;
    }

    private static IServiceCollection AddEmail(this IServiceCollection services)
    {
        services.AddSingleton<EmailQueue>();
        services.AddSingleton<IEmailSender, QueuedEmailSender>();
        services.AddSingleton<IEmailTransport>(provider =>
            provider.GetRequiredService<IOptions<EmailOptions>>().Value.IsSmtpConfigured
                ? ActivatorUtilities.CreateInstance<MailKitEmailTransport>(provider)
                : ActivatorUtilities.CreateInstance<LoggingEmailTransport>(provider));

        return services;
    }

    private static IServiceCollection AddRealtime(this IServiceCollection services)
    {
        services.AddSingleton<NoteChannelRegistry>();
        services.AddSingleton<WebSocketHandler>();
        services.AddScoped<PendingRealtimeSignals>();
        services.AddScoped<IRealtimeNotifier, WebSocketRealtimeNotifier>();

        return services;
    }

    private static IServiceCollection AddAi(this IServiceCollection services)
    {
        // SDK tự gắn khoá và URL; ở đây chỉ đặt timeout để một lần gọi treo không giữ request mãi.
        services
            .AddHttpClient(GeminiLlmService.HttpClientName)
            .ConfigureHttpClient((provider, client) =>
                client.Timeout = provider.GetRequiredService<IOptions<LlmOptions>>().Value.RequestTimeout);

        services.AddSingleton<ILlmService, GeminiLlmService>();

        return services;
    }

    private static IServiceCollection AddBackgroundJobs(this IServiceCollection services)
    {
        services.AddHostedService<EmailDispatcherJobService>();
        services.AddHostedService<EmbeddingIndexerJobService>();
        services.AddHostedService<RetentionCleanupJobService>();
        services.AddHostedService<FileCleanupJobService>();

        return services;
    }

    private static void AddValidatedOptions<TOptions>(this IServiceCollection services, string sectionName)
        where TOptions : class =>
        services
            .AddOptions<TOptions>()
            .BindConfiguration(sectionName)
            .ValidateDataAnnotations()
            .ValidateOnStart();
}
