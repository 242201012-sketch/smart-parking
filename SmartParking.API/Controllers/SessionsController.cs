using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartParking.API.Security;
using SmartParking.Application.Interfaces;
using SmartParking.Domain.Entities;
using SmartParking.Infrastructure.Persistence;

namespace SmartParking.API.Controllers;

[ApiController]
[Route("api/sessions")]
[Authorize]
public sealed class SessionsController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly IPushNotificationService _pushNotifications;

    public SessionsController(
        ApplicationDbContext context,
        IPushNotificationService pushNotifications)
    {
        _context = context;
        _pushNotifications = pushNotifications;
    }

    [HttpGet]
    public async Task<IActionResult> GetHistory(CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var sessions = await SessionQuery().AsNoTracking()
            .Where(item => item.UserId == userId && !item.IsDeleted)
            .OrderByDescending(item => item.StartedAt)
            .Take(100)
            .ToListAsync(cancellationToken);
        return Ok(sessions.Select(ToResponse));
    }

    [HttpGet("active")]
    public async Task<IActionResult> GetActive(CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var session = await SessionQuery().AsNoTracking()
            .FirstOrDefaultAsync(
                item => item.UserId == userId && item.EndedAt == null && !item.IsDeleted,
                cancellationToken);
        return session is null ? NoContent() : Ok(ToResponse(session));
    }

    [HttpPost("start")]
    public async Task<IActionResult> Start(
        [FromBody] StartParkingSessionRequest request,
        CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var plate = ApiSecurity.NormalizePlate(request.VehiclePlate ?? string.Empty);
        if (plate.Length is < 5 or > 12)
            return BadRequest(new { message = "Geçerli bir plaka girilmelidir." });
        if (await _context.ParkingSessions.AnyAsync(
            item => item.UserId == userId && item.EndedAt == null && !item.IsDeleted,
            cancellationToken))
        {
            return Conflict(new { message = "Zaten devam eden bir park oturumunuz var." });
        }

        var lot = await _context.ParkingLots.FirstOrDefaultAsync(
            item => item.Id == request.ParkingLotId && item.IsActive,
            cancellationToken);
        if (lot is null)
            return NotFound(new { message = "Otopark bulunamadı." });
        ParkingSpace? space = null;
        if (request.ParkingSpaceId is not null)
        {
            space = await _context.ParkingSpaces.FirstOrDefaultAsync(
                item => item.Id == request.ParkingSpaceId && item.ParkingLotId == lot.Id,
                cancellationToken);
            if (space is null)
                return NotFound(new { message = "Park alanı bulunamadı." });
        }

        var session = new ParkingSession
        {
            UserId = userId,
            ParkingLot = lot,
            ParkingLotId = lot.Id,
            ParkingSpace = space,
            ParkingSpaceId = space?.Id,
            VehiclePlate = plate,
            StartedAt = DateTime.UtcNow
        };
        _context.ParkingSessions.Add(session);
        _context.UserNotifications.Add(new UserNotification
        {
            UserId = userId,
            Type = "parking",
            Title = "Park süresi başladı",
            Message = $"{lot.Name} için ücretlendirme başladı."
        });
        await _context.SaveChangesAsync(cancellationToken);
        await _pushNotifications.SendToUserAsync(
            userId,
            "Park süresi başladı",
            $"{lot.Name} için ücretlendirme başladı.",
            new Dictionary<string, string> { ["screen"] = "profile" },
            cancellationToken);
        return CreatedAtAction(nameof(GetActive), new { }, ToResponse(session));
    }

    [HttpPost("{id:guid}/stop")]
    public async Task<IActionResult> Stop(Guid id, CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var session = await SessionQuery().FirstOrDefaultAsync(
            item => item.Id == id && item.UserId == userId && !item.IsDeleted,
            cancellationToken);
        if (session is null)
            return NotFound();
        if (session.EndedAt is not null)
            return Conflict(new { message = "Park oturumu zaten tamamlanmış." });

        session.EndedAt = DateTime.UtcNow;
        var minutes = Math.Max(1, (decimal)(session.EndedAt.Value - session.StartedAt).TotalMinutes);
        session.TotalAmount = Math.Round(
            session.ParkingLot.HourlyRate * minutes / 60m,
            2,
            MidpointRounding.AwayFromZero);
        session.UpdatedAt = DateTime.UtcNow;
        _context.UserNotifications.Add(new UserNotification
        {
            UserId = userId,
            Type = "payment",
            Title = "Park süresi tamamlandı",
            Message = $"Toplam tutar {session.TotalAmount:0.00} TL."
        });
        await _context.SaveChangesAsync(cancellationToken);
        await _pushNotifications.SendToUserAsync(
            userId,
            "Park süresi tamamlandı",
            $"Toplam tutar {session.TotalAmount:0.00} TL.",
            new Dictionary<string, string> { ["screen"] = "profile" },
            cancellationToken);
        return Ok(ToResponse(session));
    }

    private IQueryable<ParkingSession> SessionQuery() => _context.ParkingSessions
        .Include(item => item.ParkingLot)
        .Include(item => item.ParkingSpace);

    private static object ToResponse(ParkingSession item) => new
    {
        item.Id,
        item.ParkingLotId,
        ParkingLotName = item.ParkingLot.Name,
        item.ParkingSpaceId,
        ParkingSpaceCode = item.ParkingSpace == null ? null : item.ParkingSpace.Code,
        item.VehiclePlate,
        item.StartedAt,
        item.EndedAt,
        item.TotalAmount,
        item.PaymentStatus,
        item.CreatedAt
    };
}

public sealed record StartParkingSessionRequest(
    Guid ParkingLotId,
    Guid? ParkingSpaceId,
    string? VehiclePlate);
