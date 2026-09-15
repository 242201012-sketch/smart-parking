using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartParking.API.Security;
using SmartParking.Infrastructure.Persistence;

namespace SmartParking.API.Controllers;

[ApiController]
[Route("api/notifications")]
[Authorize]
public sealed class NotificationsController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public NotificationsController(ApplicationDbContext context) => _context = context;

    [HttpGet]
    public async Task<IActionResult> GetMine(bool unreadOnly = false, CancellationToken cancellationToken = default)
    {
        var userId = User.GetUserId();
        var query = _context.UserNotifications.AsNoTracking()
            .Where(item => item.UserId == userId && !item.IsDeleted);
        if (unreadOnly)
            query = query.Where(item => !item.IsRead);
        var items = await query.OrderByDescending(item => item.CreatedAt)
            .Take(100)
            .ToListAsync(cancellationToken);
        var unreadCount = await _context.UserNotifications.CountAsync(
            item => item.UserId == userId && !item.IsRead && !item.IsDeleted,
            cancellationToken);
        return Ok(new { unreadCount, items });
    }

    [HttpPost("{id:guid}/read")]
    public async Task<IActionResult> MarkRead(Guid id, CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var item = await _context.UserNotifications.FirstOrDefaultAsync(
            notification => notification.Id == id && notification.UserId == userId,
            cancellationToken);
        if (item is null)
            return NotFound();
        item.IsRead = true;
        item.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync(cancellationToken);
        return Ok(item);
    }

    [HttpPost("read-all")]
    public async Task<IActionResult> MarkAllRead(CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var unread = await _context.UserNotifications
            .Where(item => item.UserId == userId && !item.IsRead && !item.IsDeleted)
            .ToListAsync(cancellationToken);
        foreach (var item in unread)
        {
            item.IsRead = true;
            item.UpdatedAt = DateTime.UtcNow;
        }
        await _context.SaveChangesAsync(cancellationToken);
        return Ok(new { updated = unread.Count });
    }
}
