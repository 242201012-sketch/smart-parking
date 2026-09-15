using FirebaseAdmin.Auth;
using Microsoft.Extensions.Logging;
using SmartParking.Application.Authentication.Interfaces;
using SmartParking.Application.Authentication.Response;

namespace SmartParking.Infrastructure.Firebase;

public sealed class FirebaseExternalAuthService : IFirebaseExternalAuthService
{
    private readonly FirebaseAdminProvider _provider;
    private readonly IAuthService _authService;
    private readonly ILogger<FirebaseExternalAuthService> _logger;

    public FirebaseExternalAuthService(
        FirebaseAdminProvider provider,
        IAuthService authService,
        ILogger<FirebaseExternalAuthService> logger)
    {
        _provider = provider;
        _authService = authService;
        _logger = logger;
    }

    public bool IsEnabled => _provider.IsEnabled && _provider.Auth is not null;

    public async Task<AuthResponse> LoginAsync(
        string idToken,
        CancellationToken cancellationToken = default)
    {
        if (!IsEnabled)
        {
            return new AuthResponse
            {
                Success = false,
                Message = "Firebase kimlik doğrulaması etkin değil."
            };
        }
        if (string.IsNullOrWhiteSpace(idToken) || idToken.Length > 16_384)
        {
            return new AuthResponse
            {
                Success = false,
                Message = "Firebase kimlik belirteci geçersiz."
            };
        }

        try
        {
            cancellationToken.ThrowIfCancellationRequested();
            var token = await _provider.Auth!.VerifyIdTokenAsync(idToken);
            cancellationToken.ThrowIfCancellationRequested();

            var email = Claim(token, "email");
            var fullName = Claim(token, "name");
            var emailVerified = IsTrue(token, "email_verified");
            if (string.IsNullOrWhiteSpace(email) || !emailVerified)
            {
                return new AuthResponse
                {
                    Success = false,
                    Message = "Doğrulanmış bir Google e-posta adresi gereklidir."
                };
            }

            return await _authService.ExternalLoginAsync(
                "Firebase",
                token.Uid,
                email,
                fullName);
        }
        catch (FirebaseAuthException exception)
        {
            _logger.LogWarning(exception, "Geçersiz Firebase ID token reddedildi.");
            return new AuthResponse
            {
                Success = false,
                Message = "Google oturumu doğrulanamadı. Lütfen yeniden giriş yapın."
            };
        }
    }

    private static string Claim(FirebaseToken token, string name) =>
        token.Claims.TryGetValue(name, out var value) ? value?.ToString() ?? string.Empty : string.Empty;

    private static bool IsTrue(FirebaseToken token, string name) =>
        token.Claims.TryGetValue(name, out var value)
        && (value is true || bool.TryParse(value?.ToString(), out var parsed) && parsed);
}
