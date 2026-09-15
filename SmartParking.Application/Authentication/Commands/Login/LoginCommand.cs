using MediatR;
using SmartParking.Application.Authentication.Response;

namespace SmartParking.Application.Authentication.Commands.Login;

public record LoginCommand(
    string Email,
    string Password
) : IRequest<AuthResponse>;