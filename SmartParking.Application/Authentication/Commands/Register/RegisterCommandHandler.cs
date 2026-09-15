using MediatR;
using SmartParking.Application.Authentication.Commands.Register;
using SmartParking.Application.Authentication.Interfaces;
using SmartParking.Application.Authentication.Response;

public class RegisterCommandHandler : IRequestHandler<RegisterCommand, AuthResponse>
{
    private readonly IAuthService _authService;

    public RegisterCommandHandler(IAuthService authService)
    {
        _authService = authService;
    }

    public async Task<AuthResponse> Handle(RegisterCommand request, CancellationToken cancellationToken)
    {
        var response = await _authService.RegisterAsync(request);

        if (!response.Success)
        {
            return new AuthResponse
            {
                Success = false,
                Message = "Kayıt başarısız. Email zaten kayıtlı olabilir."
            };
        }

        return response;
    }
}
