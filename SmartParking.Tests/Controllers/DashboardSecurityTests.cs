using System.Linq;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.RateLimiting;
using SmartParking.API.Controllers;
using Xunit;

public class DashboardSecurityTests
{
    [Fact]
    public void DashboardController_RequiresAuthorization()
    {
        var attribute = typeof(DashboardController)
            .GetCustomAttributes(typeof(AuthorizeAttribute), inherit: true)
            .Cast<AuthorizeAttribute>()
            .FirstOrDefault();

        Assert.NotNull(attribute);
    }

    [Fact]
    public void DashboardController_RequiresDashboardRateLimit()
    {
        var attribute = typeof(DashboardController)
            .GetCustomAttributes(typeof(EnableRateLimitingAttribute), inherit: true)
            .Cast<EnableRateLimitingAttribute>()
            .FirstOrDefault();

        Assert.NotNull(attribute);
        Assert.Equal("dashboard", attribute.PolicyName);
    }
}
