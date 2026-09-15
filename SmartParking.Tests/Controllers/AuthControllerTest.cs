using System.Threading.Tasks;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Moq;
using SmartParking.API.Controllers;
using SmartParking.Application.Authentication.Commands.Login;
using SmartParking.Application.Authentication.Interfaces;
using SmartParking.Application.Authentication.Response;
using Xunit;

public class AuthControllerTests
{
    [Fact]
    public async Task Login_ShouldReturnOkResult_WhenValidCommand()
    {
        // Arrange
        var mediatorMock = new Mock<IMediator>();
        mediatorMock.Setup(m => m.Send(It.IsAny<LoginCommand>(), default))
            .ReturnsAsync(new AuthResponse { Success = true, AccessToken = "fake-token" });

        var firebaseAuthMock = new Mock<IFirebaseExternalAuthService>();
        var controller = new AuthController(mediatorMock.Object, firebaseAuthMock.Object);

        // Act
        var result = await controller.Login(new LoginCommand("test@example.com", "Password123!"));

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<AuthResponse>(okResult.Value);
        Assert.True(response.Success);
        Assert.Equal("fake-token", response.AccessToken);
    }

    [Fact]
    public async Task FirebaseLogin_ShouldReturnOk_WhenFirebaseTokenIsValid()
    {
        var mediatorMock = new Mock<IMediator>();
        var firebaseAuthMock = new Mock<IFirebaseExternalAuthService>();
        firebaseAuthMock.SetupGet(service => service.IsEnabled).Returns(true);
        firebaseAuthMock
            .Setup(service => service.LoginAsync("firebase-id-token", default))
            .ReturnsAsync(new AuthResponse
            {
                Success = true,
                AccessToken = "smartparking-token"
            });
        var controller = new AuthController(mediatorMock.Object, firebaseAuthMock.Object);

        var result = await controller.FirebaseLogin(
            new FirebaseLoginRequest("firebase-id-token"),
            default);

        var okResult = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<AuthResponse>(okResult.Value);
        Assert.Equal("smartparking-token", response.AccessToken);
    }

    [Fact]
    public async Task FirebaseLogin_ShouldReturnServiceUnavailable_WhenFirebaseIsDisabled()
    {
        var mediatorMock = new Mock<IMediator>();
        var firebaseAuthMock = new Mock<IFirebaseExternalAuthService>();
        firebaseAuthMock.SetupGet(service => service.IsEnabled).Returns(false);
        var controller = new AuthController(mediatorMock.Object, firebaseAuthMock.Object);

        var result = await controller.FirebaseLogin(
            new FirebaseLoginRequest("firebase-id-token"),
            default);

        var objectResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(503, objectResult.StatusCode);
    }
}
