using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using SmartParking.Application.Authentication.Interfaces;
using SmartParking.Application.Interfaces;
using SmartParking.Infrastructure.Identity;
using SmartParking.Infrastructure.Firebase;
using SmartParking.Infrastructure.Persistence;
using SmartParking.Infrastructure.Payments;
using SmartParking.Infrastructure.Services;
using SmartParking.Infrastructure.Telemetry;
using System.Text;
using Npgsql;

namespace SmartParking.Infrastructure.DependencyInjection;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // 🔐 JWT SETTINGS
        services.Configure<JwtSettings>(configuration.GetSection("Jwt"));
        var jwt = configuration.GetSection("Jwt").Get<JwtSettings>()
            ?? throw new InvalidOperationException("Jwt ayarları bulunamadı.");
        if (string.IsNullOrWhiteSpace(jwt.Key)
            || jwt.Key.Length < 32
            || jwt.Key == "CHANGE_ME_WITH_A_32_CHARACTER_SECRET")
        {
            throw new InvalidOperationException(
                "Jwt:Key en az 32 karakterlik, uygulamaya özel bir gizli değer olmalıdır.");
        }

        // 🧩 DATABASE
        var connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("DefaultConnection bulunamadı.");
        var provider = configuration["Database:Provider"];
        var usePostgres = string.Equals(provider, "PostgreSQL", StringComparison.OrdinalIgnoreCase)
            || connectionString.StartsWith("postgres://", StringComparison.OrdinalIgnoreCase)
            || connectionString.StartsWith("postgresql://", StringComparison.OrdinalIgnoreCase);
        var useSqlite = string.Equals(provider, "SQLite", StringComparison.OrdinalIgnoreCase);

        services.AddDbContext<ApplicationDbContext>(options =>
        {
            if (usePostgres)
                options.UseNpgsql(NormalizePostgresConnectionString(connectionString));
            else if (useSqlite)
                options.UseSqlite(connectionString);
            else
                options.UseSqlServer(connectionString);
        });

        // 👥 IDENTITY
        services.AddIdentityCore<AppUser>(options =>
        {
            options.User.RequireUniqueEmail = true;
        })
        .AddRoles<IdentityRole<Guid>>()
        .AddEntityFrameworkStores<ApplicationDbContext>()
        .AddDefaultTokenProviders();

        // 🔑 JWT AUTHENTICATION
        services.AddAuthentication(options =>
        {
            options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
            options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
            options.DefaultScheme = JwtBearerDefaults.AuthenticationScheme;
        })
        .AddJwtBearer(options =>
        {
            options.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidateAudience = true,
                ValidateLifetime = true,
                ValidateIssuerSigningKey = true,
                ValidIssuer = jwt.Issuer,
                ValidAudience = jwt.Audience,
                IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Key)),
                ClockSkew = TimeSpan.FromSeconds(30)
            };

            options.Events = new JwtBearerEvents
            {
                OnMessageReceived = context =>
                {
                    var accessToken = context.Request.Query["access_token"];
                    if (!string.IsNullOrEmpty(accessToken)
                        && context.HttpContext.Request.Path.StartsWithSegments("/hubs/parking"))
                    {
                        context.Token = accessToken;
                    }
                    return Task.CompletedTask;
                }
            };
        });

        // 🧠 SERVICES
        services.AddScoped<IJwtService, JwtService>();
        services.AddScoped<IAuthService, AuthService>();
        services.AddScoped<IParkingService, ParkingService>();
        services.AddOptions<FirebaseSettings>()
            .Bind(configuration.GetSection("Firebase"))
            .Validate(
                settings => !settings.Enabled || !string.IsNullOrWhiteSpace(settings.ProjectId),
                "Firebase etkinse Firebase:ProjectId zorunludur.")
            .Validate(
                settings => settings.ServiceAccountJson is null
                    || settings.ServiceAccountJson.Length <= 100_000,
                "Firebase servis hesabı JSON'u beklenen boyutu aşıyor.")
            .ValidateOnStart();
        services.AddSingleton<FirebaseAdminProvider>();
        services.AddScoped<IFirebaseExternalAuthService, FirebaseExternalAuthService>();
        services.AddScoped<IPushNotificationService, FirebasePushNotificationService>();
services.AddOptions<IyzicoSettings>()
            .Bind(configuration.GetSection("Payment"));
        services.AddScoped<ICardPaymentService, IyzicoCardPaymentService>();

        // MongoDB / AWS DocumentDB telemetri deposu. ConnectionString boşsa
        // NoOp ile mevcut EF Core kaydı tek depo olarak çalışmaya devam eder.
        var mongoConnectionString = configuration["DocumentDb:ConnectionString"];
        if (string.IsNullOrWhiteSpace(mongoConnectionString))
        {
            services.AddSingleton<ITelemetryStore, NoOpTelemetryStore>();
        }
        else
        {
            services.Configure<MongoTelemetryStoreOptions>(configuration.GetSection("DocumentDb"));
            services.AddOptions<MongoTelemetryStoreOptions>()
                .Bind(configuration.GetSection("DocumentDb"))
                .Validate(options => !string.IsNullOrWhiteSpace(options.ConnectionString), "DocumentDb:ConnectionString gereklidir.")
                .ValidateOnStart();
            services.AddSingleton<ITelemetryStore, MongoTelemetryStore>();
        }

        return services;
    }

    private static string NormalizePostgresConnectionString(string connectionString)
    {
        if (!connectionString.StartsWith("postgres://", StringComparison.OrdinalIgnoreCase)
            && !connectionString.StartsWith("postgresql://", StringComparison.OrdinalIgnoreCase))
        {
            return connectionString;
        }

        var uri = new Uri(connectionString);
        var userInfo = uri.UserInfo.Split(':', 2);
        var builder = new NpgsqlConnectionStringBuilder
        {
            Host = uri.Host,
            Port = uri.Port > 0 ? uri.Port : 5432,
            Username = Uri.UnescapeDataString(userInfo[0]),
            Password = userInfo.Length > 1 ? Uri.UnescapeDataString(userInfo[1]) : string.Empty,
            Database = uri.AbsolutePath.Trim('/'),
            SslMode = SslMode.Prefer,
            Timeout = 15,
            KeepAlive = 30
        };
        return builder.ConnectionString;
    }
}
