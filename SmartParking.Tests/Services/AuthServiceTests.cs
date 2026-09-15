using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Identity;
using Moq;
using SmartParking.Application.Authentication.Commands.Login;
using SmartParking.Application.Authentication.Commands.Register;
using SmartParking.Application.Authentication.Interfaces;
using SmartParking.Infrastructure.Identity;
using Xunit;

public class AuthServiceTests
{
    private readonly Mock<UserManager<AppUser>> _userManagerMock;
    private readonly Mock<IJwtService> _jwtServiceMock;
    private readonly AuthService _authService;

    public AuthServiceTests()
    {
        var store = new Mock<IUserStore<AppUser>>();
        _userManagerMock = new Mock<UserManager<AppUser>>(store.Object, null, null, null, null, null, null, null, null);
        _jwtServiceMock = new Mock<IJwtService>();

        _authService = new AuthService(_userManagerMock.Object, _jwtServiceMock.Object);
    }

    [Fact]
    public async Task RegisterAsync_ShouldReturnSuccess_WhenUserCreated()
    {
        // Arrange
        var command = new RegisterCommand("Test User", "test@example.com", "Password123!");
        _userManagerMock.Setup(x => x.CreateAsync(It.IsAny<AppUser>(), command.Password))
            .ReturnsAsync(IdentityResult.Success);
        _userManagerMock.Setup(x => x.UpdateAsync(It.IsAny<AppUser>()))
            .ReturnsAsync(IdentityResult.Success);
        _userManagerMock.Setup(x => x.IsInRoleAsync(It.IsAny<AppUser>(), "User"))
            .ReturnsAsync(false);
        _userManagerMock.Setup(x => x.AddToRoleAsync(It.IsAny<AppUser>(), "User"))
            .ReturnsAsync(IdentityResult.Success);
        _userManagerMock.Setup(x => x.GetRolesAsync(It.IsAny<AppUser>()))
            .ReturnsAsync(new List<string> { "User" });
        _jwtServiceMock.Setup(x => x.CreateToken(It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<IList<string>>()))
            .Returns("fake-jwt-token");
        _jwtServiceMock.Setup(x => x.CreateRefreshToken()).Returns("fake-refresh-token");

        // Act
        var result = await _authService.RegisterAsync(command);

        // Assert
        Assert.True(result.Success);
        Assert.Equal("Kayıt başarılı.", result.Message);
        Assert.Equal("fake-jwt-token", result.AccessToken);
        Assert.Equal("fake-refresh-token", result.RefreshToken);
    }
}
