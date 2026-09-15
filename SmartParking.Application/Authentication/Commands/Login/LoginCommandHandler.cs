using MediatR;
using SmartParking.Application.Authentication.Commands.Login;
using SmartParking.Application.Authentication.Interfaces;
using SmartParking.Application.Authentication.Response;

public class LoginCommandHandler : IRequestHandler<LoginCommand, AuthResponse>
{
    private readonly IAuthService _authService;

    public LoginCommandHandler(IAuthService authService)
    {
        _authService = authService;
    }

    public async Task<AuthResponse> Handle(LoginCommand request, CancellationToken cancellationToken)
    {
        var response = await _authService.LoginAsync(request);

        if (!response.Success)
        {
            return new AuthResponse
            {
                Success = false,
                Message = "Giriş başarısız. Email veya şifre hatalı."
            };
        }

        return response;
    }
}
