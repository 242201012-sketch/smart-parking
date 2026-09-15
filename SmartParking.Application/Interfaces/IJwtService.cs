namespace SmartParking.Application.Authentication.Interfaces;

public interface IJwtService
{
    string CreateToken(Guid userId, string email, IList<string> roles);
    string CreateRefreshToken();
    bool ValidateToken(string token);
}
