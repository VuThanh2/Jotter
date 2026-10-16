using Jotter.Api;
using Jotter.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddInfrastructure(builder.Configuration)
    .AddPresentation(builder.Configuration);

var app = builder.Build();

app.UsePresentation();
app.MapPresentation();

await app.ApplyMigrationsAsync();
await app.RunAsync();
