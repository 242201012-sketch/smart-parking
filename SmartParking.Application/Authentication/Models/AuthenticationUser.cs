namespace SmartParking.Application.Authentication.Models;

public class AuthenticationUser
{
    public Guid Id { get; set; }

    public string FullName { get; set; } = "";

    public string Email { get; set; } = "";

    public IList<string> Roles { get; set; }
        = new List<string>();
}
