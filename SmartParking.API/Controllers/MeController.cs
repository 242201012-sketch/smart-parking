using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartParking.API.Security;
using SmartParking.Infrastructure.Identity;
using SmartParking.Infrastructure.Persistence;

namespace SmartParking.API.Controllers;

[ApiController]
[Route("api/me")]
[Authorize]
public sealed class MeController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly UserManager<AppUser> _userManager;

    public MeController(ApplicationDbContext context, UserManager<AppUser> userManager)
    {
        _context = context;
        _userManager = userManager;
    }

    [HttpGet]
    public async Task<IActionResult> GetProfile(CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var user = await _userManager.FindByIdAsync(userId.ToString());
        if (user is null)
            return NotFound();
        var roles = await _userManager.GetRolesAsync(user);
        return Ok(new
        {
            user.Id,
            user.FullName,
            user.Email,
            roles,
            user.CreatedAt,
            favoriteCount = await _context.Favorites.CountAsync(
                item => item.UserId == userId && !item.IsDeleted,
                cancellationToken),
            unreadNotificationCount = await _context.UserNotifications.CountAsync(
                item => item.UserId == userId && !item.IsRead && !item.IsDeleted,
                cancellationToken),
            vehicles = await _context.Vehicles.AsNoTracking()
                .Where(item => item.UserId == userId && !item.IsDeleted)
                .Select(item => new { item.Id, item.PlateNumber, item.Brand, item.Model, item.Color })
                .ToListAsync(cancellationToken)
        });
    }
}
