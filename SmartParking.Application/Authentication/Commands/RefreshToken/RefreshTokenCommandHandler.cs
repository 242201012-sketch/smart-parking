using MediatR;
using SmartParking.Application.Authentication.Interfaces;
using SmartParking.Application.Authentication.Response;

namespace SmartParking.Application.Authentication.Commands.RefreshToken;

public class RefreshTokenCommandHandler : IRequestHandler<RefreshTokenCommand, AuthResponse>
{
    private readonly IAuthService _authService;

    public RefreshTokenCommandHandler(IAuthService authService)
    {
        _authService = authService;
    }

    public async Task<AuthResponse> Handle(RefreshTokenCommand request, CancellationToken cancellationToken)
    {
        var response = await _authService.RefreshTokenAsync(request.RefreshToken);

        if (!response.Success)
        {
            return new AuthResponse
            {
                Success = false,
                Message = "Refresh token geçersiz veya süresi dolmuş."
            };
        }

        return response;
    }
}
