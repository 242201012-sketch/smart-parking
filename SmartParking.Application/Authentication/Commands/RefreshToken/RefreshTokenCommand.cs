using MediatR;
using SmartParking.Application.Authentication.Response;

namespace SmartParking.Application.Authentication.Commands.RefreshToken;

public record RefreshTokenCommand(string RefreshToken) : IRequest<AuthResponse>;
