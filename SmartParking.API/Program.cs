using System.Threading.RateLimiting;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;
using SmartParking.API.BackgroundServices;
using SmartParking.API.Health;
using SmartParking.API.Hubs;
using SmartParking.Application;
using SmartParking.Infrastructure.DependencyInjection;
using SmartParking.Infrastructure.Persistence;

var builder = WebApplication.CreateBuilder(args);

if (int.TryParse(Environment.GetEnvironmentVariable("PORT"), out var port))
    builder.WebHost.UseUrls($"http://0.0.0.0:{port}");

// Katmanları ekle
builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration);

// Controller ve Swagger
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.CustomSchemaIds(type => type.FullName?.Replace('+', '.') ?? type.Name);
});
builder.Services.AddHttpClient("AnprTensorRt");
builder.Services.AddSignalR();
builder.Services.AddHealthChecks()
    .AddCheck<DatabaseHealthCheck>("database");
builder.Services.AddHostedService<ReservationExpiryService>();
builder.Services.AddHostedService<TelemetryRetentionService>();
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddFixedWindowLimiter("auth", limiter =>
    {
        limiter.PermitLimit = 20;
        limiter.Window = TimeSpan.FromMinutes(1);
        limiter.QueueLimit = 0;
    });
    options.AddFixedWindowLimiter("sensor", limiter =>
    {
        limiter.PermitLimit = 240;
        limiter.Window = TimeSpan.FromMinutes(1);
        limiter.QueueLimit = 20;
        limiter.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
    });
    options.AddFixedWindowLimiter("payment", limiter =>
    {
        limiter.PermitLimit = 10;
        limiter.Window = TimeSpan.FromMinutes(1);
        limiter.QueueLimit = 0;
    });
    options.AddFixedWindowLimiter("payment-callback", limiter =>
    {
        limiter.PermitLimit = 120;
        limiter.Window = TimeSpan.FromMinutes(1);
        limiter.QueueLimit = 10;
        limiter.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
    });
});
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.KnownIPNetworks.Clear();
    options.KnownProxies.Clear();
});

var allowedOrigins = builder.Configuration
    .GetSection("Cors:AllowedOrigins")
    .Get<string[]>()
    ?.Where(origin => !string.IsNullOrWhiteSpace(origin))
    .ToArray() ?? Array.Empty<string>();
builder.Services.AddCors(options =>
{
    options.AddPolicy("MobileClients", policy =>
    {
        if (allowedOrigins.Length > 0)
            policy.WithOrigins(allowedOrigins).AllowCredentials();
        else if (builder.Environment.IsDevelopment())
            policy.AllowAnyOrigin();
        else
            throw new InvalidOperationException("Üretimde Cors:AllowedOrigins tanımlanmalıdır.");

        policy.AllowAnyHeader().AllowAnyMethod();
    });
});

var app = builder.Build();

if (builder.Configuration.GetValue("Database:ApplyMigrationsOnStartup", true))
    await DatabaseSeeder.SeedAsync(app.Services);

// Swagger UI
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseForwardedHeaders();
if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
    app.UseHttpsRedirection();
}

app.Use(async (context, next) =>
{
    context.Response.Headers["X-Content-Type-Options"] = "nosniff";
    context.Response.Headers["X-Frame-Options"] = "DENY";
    context.Response.Headers["Referrer-Policy"] = "no-referrer";
    await next();
});

app.UseCors("MobileClients");
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHub<ParkingHub>("/hubs/parking");
app.MapHealthChecks("/health");
app.MapGet("/", () => Results.Ok(new
{
    service = "SmartParking API",
    status = "ok",
    version = "5.0",
    capabilities = new[]
    {
        "android",
        "google-maps",
        "firebase-auth",
        "firebase-cloud-messaging",
        "cloud-run",
        "offline-cache-and-sync",
        "mobile-admin",
        "turkiye-81-province-coverage",
        "iyzico-hosted-card-payment"
    }
}));

app.Run();
