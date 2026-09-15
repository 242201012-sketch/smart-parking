using System;
using Microsoft.Extensions.Options;
using SmartParking.Infrastructure.Identity;
using Xunit;

public class JwtServiceTests
{
    private readonly JwtService _jwtService;

    public JwtServiceTests()
    {
        var settings = Options.Create(new JwtSettings
        {
            Key = "SUPER_SECRET_KEY_12345678901234567890",
            Issuer = "SmartParkingAPI",
            Audience = "SmartParkingClient",
            ExpireMinutes = 60
        });

        _jwtService = new JwtService(settings);
    }

    [Fact]
    public void CreateToken_ShouldReturnValidJwt()
    {
        // Act
        var token = _jwtService.CreateToken(Guid.NewGuid(), "test@example.com", new[] { "User" });

        // Assert
        Assert.False(string.IsNullOrEmpty(token));
    }

    [Fact]
    public void CreateRefreshToken_ShouldReturnNonEmptyString()
    {
        var refreshToken = _jwtService.CreateRefreshToken();
        Assert.False(string.IsNullOrEmpty(refreshToken));
    }
}
