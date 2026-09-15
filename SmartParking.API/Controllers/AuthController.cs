using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using SmartParking.Application.Authentication.Commands.Login;
using SmartParking.Application.Authentication.Commands.RefreshToken;
using SmartParking.Application.Authentication.Commands.Register;
using SmartParking.Application.Authentication.DTO;
using SmartParking.Application.Authentication.Interfaces;
using SmartParking.Application.Authentication.Response;

namespace SmartParking.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[EnableRateLimiting("auth")]
public class AuthController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly IFirebaseExternalAuthService _firebaseAuth;

    public AuthController(IMediator mediator, IFirebaseExternalAuthService firebaseAuth)
    {
        _mediator = mediator;
        _firebaseAuth = firebaseAuth;
    }

    /// <summary>
    /// Firebase/Google ID token doğrular ve SmartParking JWT oturumu oluşturur.
    /// </summary>
    [HttpPost("firebase")]
    public async Task<IActionResult> FirebaseLogin(
        [FromBody] FirebaseLoginRequest request,
        CancellationToken cancellationToken)
    {
        if (!_firebaseAuth.IsEnabled)
        {
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new
            {
                success = false,
                message = "Firebase kimlik doğrulaması sunucuda etkin değil."
            });
        }

        var result = await _firebaseAuth.LoginAsync(request.IdToken, cancellationToken);
        return result.Success ? Ok(result) : Unauthorized(result);
    }

    /// <summary>
    /// Kullanıcı kaydı oluşturur.
    /// </summary>
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterCommand command)
    {
        var result = await _mediator.Send(command);
        if (!result.Success)
            return BadRequest(result);

        return Ok(result);
    }

    /// <summary>
    /// Kullanıcı giriş işlemi yapar.
    /// </summary>
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginCommand command)
    {
        var result = await _mediator.Send(command);
        if (!result.Success)
            return Unauthorized(result);

        return Ok(result);
    }

    /// <summary>
    /// Refresh token ile yeni access token üretir.
    /// </summary>
    [HttpPost("refresh-token")]
    public async Task<IActionResult> RefreshToken([FromBody] RefreshTokenRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.RefreshToken))
            return BadRequest(new { Message = "Refresh token gereklidir." });

        var command = new RefreshTokenCommand(request.RefreshToken);
        var result = await _mediator.Send(command);
        if (!result.Success)
            return BadRequest(result);

        return Ok(result);
    }
}

public sealed record FirebaseLoginRequest(string IdToken);
