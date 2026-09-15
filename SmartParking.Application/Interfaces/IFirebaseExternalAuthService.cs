using SmartParking.Application.Authentication.Response;

namespace SmartParking.Application.Authentication.Interfaces;

public interface IFirebaseExternalAuthService
{
    bool IsEnabled { get; }

    Task<AuthResponse> LoginAsync(string idToken, CancellationToken cancellationToken = default);
}
