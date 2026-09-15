namespace SmartParking.Application.Authentication.DTO;

public sealed class RefreshTokenRequest
{
    public string RefreshToken { get; set; } = string.Empty;
}
