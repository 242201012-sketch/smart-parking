using SmartParking.Application.Authentication.Commands.Login;
using SmartParking.Application.Authentication.Commands.Register;
using SmartParking.Application.Authentication.Response;

namespace SmartParking.Application.Authentication.Interfaces;

public interface IAuthService
{
    Task<AuthResponse> RegisterAsync(RegisterCommand command);
    Task<AuthResponse> LoginAsync(LoginCommand command);
    Task<AuthResponse> RefreshTokenAsync(string refreshToken);
    Task<AuthResponse> ExternalLoginAsync(
        string provider,
        string providerKey,
        string email,
        string fullName);
}
