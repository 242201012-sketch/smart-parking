using System.Data;
using System.Security.Cryptography;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using SmartParking.API.Hubs;
using SmartParking.API.Security;
using SmartParking.Application.Interfaces;
using SmartParking.Domain.Entities;
using SmartParking.Infrastructure.Persistence;

namespace SmartParking.API.Controllers;

[ApiController]
[Route("api/reservations")]
[Authorize]
public sealed class ReservationsController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly IHubContext<ParkingHub> _hub;
    private readonly IPushNotificationService _pushNotifications;

    public ReservationsController(
        ApplicationDbContext context,
        IHubContext<ParkingHub> hub,
        IPushNotificationService pushNotifications)
    {
        _context = context;
        _hub = hub;
        _pushNotifications = pushNotifications;
    }

    [HttpGet]
    public async Task<IActionResult> GetMine(CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var reservations = await _context.Reservations
            .AsNoTracking()
            .Include(item => item.Vehicle)
            .Include(item => item.ParkingSpace)
                .ThenInclude(space => space.ParkingLot)
            .Where(item => item.UserId == userId && !item.IsDeleted)
            .OrderByDescending(item => item.CreatedAt)
            .Take(100)
            .ToListAsync(cancellationToken);
        return Ok(reservations.Select(ToResponse));
    }

    [HttpGet("active")]
    public async Task<IActionResult> GetActive(CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var now = DateTime.UtcNow;
        var reservation = await ReservationQuery()
            .AsNoTracking()
            .FirstOrDefaultAsync(
                item => item.UserId == userId && item.IsActive && item.EndTime > now,
                cancellationToken);
        return reservation is null ? NoContent() : Ok(ToResponse(reservation));
    }

    [HttpPost]
    public async Task<IActionResult> Create(
        [FromBody] CreateReservationRequest request,
        CancellationToken cancellationToken)
    {
        if (request.DurationMinutes is < 5 or > 240)
            return BadRequest(new { message = "Rezervasyon süresi 5-240 dakika arasında olmalıdır." });
        var plate = ApiSecurity.NormalizePlate(request.VehiclePlate ?? string.Empty);
        if (plate.Length is < 5 or > 12)
            return BadRequest(new { message = "Geçerli bir plaka girilmelidir." });

        var userId = User.GetUserId();
        var now = DateTime.UtcNow;
        await using var transaction = await _context.Database.BeginTransactionAsync(
            IsolationLevel.Serializable,
            cancellationToken);

        var alreadyActive = await _context.Reservations.AnyAsync(
            item => item.UserId == userId && item.IsActive && item.EndTime > now,
            cancellationToken);
        if (alreadyActive)
            return Conflict(new { message = "Zaten aktif bir rezervasyonunuz var." });

        var lot = await _context.ParkingLots
            .Include(item => item.Spaces)
            .FirstOrDefaultAsync(
                item => item.Id == request.ParkingLotId && item.IsActive,
                cancellationToken);
        if (lot is null)
            return NotFound(new { message = "Otopark bulunamadı." });

        var candidates = lot.Spaces
            .Where(space => !space.IsOccupied && (!space.IsReserved || space.ReservedUntil <= now));
        if (request.RequireElectric)
            candidates = candidates.Where(space => space.IsElectric);
        if (request.RequireAccessible)
            candidates = candidates.Where(space => space.IsAccessible);
        var space = candidates.OrderBy(item => item.Code).FirstOrDefault();
        if (space is null)
            return Conflict(new { message = "İstenen özelliklerde boş park alanı kalmadı." });

        var vehicle = await _context.Vehicles.FirstOrDefaultAsync(
            item => item.UserId == userId && item.PlateNumber == plate && !item.IsDeleted,
            cancellationToken);
        if (vehicle is null)
        {
            vehicle = new Vehicle
            {
                UserId = userId,
                PlateNumber = plate,
                Brand = request.VehicleBrand?.Trim() ?? string.Empty,
                Model = request.VehicleModel?.Trim() ?? string.Empty,
                Color = request.VehicleColor?.Trim() ?? string.Empty
            };
            _context.Vehicles.Add(vehicle);
        }

        var endTime = now.AddMinutes(request.DurationMinutes);
        var estimatedAmount = Math.Round(
            lot.HourlyRate * request.DurationMinutes / 60m,
            2,
            MidpointRounding.AwayFromZero);
        var reservation = new Reservation
        {
            UserId = userId,
            Vehicle = vehicle,
            VehicleId = vehicle.Id,
            ParkingSpace = space,
            ParkingSpaceId = space.Id,
            StartTime = now,
            EndTime = endTime,
            IsActive = true,
            QrToken = RandomNumberGenerator.GetHexString(32),
            EstimatedAmount = estimatedAmount
        };
        space.IsReserved = true;
        space.ReservedUntil = endTime;
        space.UpdatedAt = now;
        _context.Reservations.Add(reservation);
        _context.UserNotifications.Add(new UserNotification
        {
            UserId = userId,
            Type = "reservation",
            Title = "Yeriniz ayrıldı",
            Message = $"{lot.Name} · {space.Code}, {request.DurationMinutes} dakika boyunca sizin için ayrıldı.",
            ActionUrl = "/#asistan"
        });
        await _context.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        await _hub.Clients.All.SendAsync(
            "ParkingLotRefreshRequested",
            lot.Id.ToString(),
            cancellationToken);
        await _pushNotifications.SendToUserAsync(
            userId,
            "Yeriniz ayrıldı",
            $"{lot.Name} · {space.Code}, {request.DurationMinutes} dakika boyunca sizin için ayrıldı.",
            new Dictionary<string, string>
            {
                ["screen"] = "reservation",
                ["reservationId"] = reservation.Id.ToString()
            },
            cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = reservation.Id }, ToResponse(reservation));
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id, CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var reservation = await ReservationQuery()
            .AsNoTracking()
            .FirstOrDefaultAsync(item => item.Id == id && item.UserId == userId, cancellationToken);
        return reservation is null ? NotFound() : Ok(ToResponse(reservation));
    }

    [HttpPost("{id:guid}/cancel")]
    public async Task<IActionResult> Cancel(Guid id, CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var reservation = await ReservationQuery()
            .FirstOrDefaultAsync(item => item.Id == id && item.UserId == userId, cancellationToken);
        if (reservation is null)
            return NotFound();
        if (!reservation.IsActive)
            return Conflict(new { message = "Rezervasyon zaten kapalı." });

        reservation.IsActive = false;
        reservation.IsCancelled = true;
        reservation.UpdatedAt = DateTime.UtcNow;
        reservation.ParkingSpace.IsReserved = false;
        reservation.ParkingSpace.ReservedUntil = null;
        reservation.ParkingSpace.UpdatedAt = DateTime.UtcNow;
        _context.UserNotifications.Add(new UserNotification
        {
            UserId = userId,
            Type = "reservation",
            Title = "Rezervasyon iptal edildi",
            Message = $"{reservation.ParkingSpace.ParkingLot.Name} rezervasyonunuz iptal edildi."
        });
        await _context.SaveChangesAsync(cancellationToken);
        await _hub.Clients.All.SendAsync(
            "ParkingLotRefreshRequested",
            reservation.ParkingSpace.ParkingLotId.ToString(),
            cancellationToken);
        await _pushNotifications.SendToUserAsync(
            userId,
            "Rezervasyon iptal edildi",
            $"{reservation.ParkingSpace.ParkingLot.Name} rezervasyonunuz iptal edildi.",
            new Dictionary<string, string> { ["screen"] = "parking" },
            cancellationToken);
        return Ok(ToResponse(reservation));
    }

    [HttpPost("validate")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> ValidateQr(
        [FromBody] ValidateReservationRequest request,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var reservation = await ReservationQuery()
            .AsNoTracking()
            .FirstOrDefaultAsync(item => item.QrToken == request.QrToken, cancellationToken);
        if (reservation is null)
            return NotFound(new { valid = false, message = "Rezervasyon bulunamadı." });
        var valid = reservation.IsActive && !reservation.IsCancelled && reservation.EndTime > now;
        return Ok(new { valid, reservation = ToResponse(reservation) });
    }

    private IQueryable<Reservation> ReservationQuery() => _context.Reservations
        .Include(item => item.Vehicle)
        .Include(item => item.ParkingSpace)
            .ThenInclude(space => space.ParkingLot);

    private static object ToResponse(Reservation item) => new
    {
        item.Id,
        item.UserId,
        item.ParkingSpace.ParkingLotId,
        ParkingLotName = item.ParkingSpace.ParkingLot.Name,
        item.ParkingSpace.ParkingLot.Address,
        item.ParkingSpace.ParkingLot.Latitude,
        item.ParkingSpace.ParkingLot.Longitude,
        ParkingSpaceId = item.ParkingSpaceId,
        ParkingSpaceCode = item.ParkingSpace.Code,
        VehiclePlate = item.Vehicle.PlateNumber,
        item.StartTime,
        item.EndTime,
        item.IsActive,
        item.IsCancelled,
        item.Status,
        item.QrToken,
        item.EstimatedAmount,
        item.CreatedAt
    };
}

public sealed record CreateReservationRequest(
    Guid ParkingLotId,
    string? VehiclePlate,
    int DurationMinutes,
    bool RequireElectric = false,
    bool RequireAccessible = false,
    string? VehicleBrand = null,
    string? VehicleModel = null,
    string? VehicleColor = null);

public sealed record ValidateReservationRequest(string QrToken);
