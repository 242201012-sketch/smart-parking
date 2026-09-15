using FirebaseAdmin;
using FirebaseAdmin.Auth;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace SmartParking.Infrastructure.Firebase;

public sealed class FirebaseAdminProvider : IDisposable
{
    private readonly FirebaseSettings _settings;
    private readonly ILogger<FirebaseAdminProvider> _logger;
    private readonly Lazy<FirebaseApp?> _app;

    public FirebaseAdminProvider(
        IOptions<FirebaseSettings> settings,
        ILogger<FirebaseAdminProvider> logger)
    {
        _settings = settings.Value;
        _logger = logger;
        _app = new Lazy<FirebaseApp?>(CreateApp, LazyThreadSafetyMode.ExecutionAndPublication);
    }

    public bool IsEnabled => _settings.Enabled && !string.IsNullOrWhiteSpace(_settings.ProjectId);

    public FirebaseAuth? Auth => _app.Value is { } app
        ? FirebaseAuth.GetAuth(app)
        : null;

    public FirebaseMessaging? Messaging => _app.Value is { } app
        ? FirebaseMessaging.GetMessaging(app)
        : null;

    private FirebaseApp? CreateApp()
    {
        if (!IsEnabled) return null;

        try
        {
            var credential = string.IsNullOrWhiteSpace(_settings.ServiceAccountJson)
                ? GoogleCredential.GetApplicationDefault()
                : GoogleCredential.FromJson(_settings.ServiceAccountJson);
            return FirebaseApp.Create(
                new AppOptions
                {
                    Credential = credential,
                    ProjectId = _settings.ProjectId
                },
                $"smartparking-{Guid.NewGuid():N}");
        }
        catch (Exception exception)
        {
            _logger.LogError(exception, "Firebase Admin başlatılamadı.");
            return null;
        }
    }

    public void Dispose()
    {
        if (_app.IsValueCreated) _app.Value?.Delete();
    }
}
