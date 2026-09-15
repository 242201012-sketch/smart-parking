using MediatR;
using SmartParking.Application.Authentication.Response;

namespace SmartParking.Application.Authentication.Commands.Register;

public record RegisterCommand(
    string FullName,
    string Email,
    string Password
) : IRequest<AuthResponse>;