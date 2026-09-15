using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartParking.Domain.Entities;
using SmartParking.Infrastructure.Persistence;

namespace SmartParking.API.Controllers;

[ApiController]
[Route("api/admin")]
[Authorize(Roles = "Admin")]
public sealed class AdminController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public AdminController(ApplicationDbContext context) => _context = context;

    [HttpGet("dashboard")]
    public async Task<IActionResult> GetDashboard(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var since = now.AddHours(-24);
        var lots = await _context.ParkingLots.AsNoTracking()
            .Where(item => item.IsActive)
            .Select(item => new
            {
                item.Id,
                item.Name,
                item.TotalCapacity,
                item.AvailableCapacity,
                occupancyPercent = item.TotalCapacity == 0
                    ? 0
                    : Math.Round((item.TotalCapacity - item.AvailableCapacity) * 100d / item.TotalCapacity, 1),
                item.UpdatedAt
            })
            .ToListAsync(cancellationToken);
        var sensorDevices = await _context.SensorDevices.CountAsync(
            item => item.IsActive && !item.IsDeleted,
            cancellationToken);
        var onlineSensors = await _context.SensorDevices.CountAsync(
            item => item.IsActive && !item.IsDeleted && item.LastSeenAt >= now.AddMinutes(-5),
            cancellationToken);
        return Ok(new
        {
            generatedAt = now,
            totals = new
            {
                users = await _context.Users.CountAsync(cancellationToken),
                parkingLots = lots.Count,
                spaces = lots.Sum(item => item.TotalCapacity),
                availableSpaces = lots.Sum(item => item.AvailableCapacity),
                activeReservations = await _context.Reservations.CountAsync(
                    item => item.IsActive && item.EndTime > now,
                    cancellationToken),
                activeSessions = await _context.ParkingSessions.CountAsync(
                    item => item.EndedAt == null && !item.IsDeleted,
                    cancellationToken),
                readingsLast24Hours = await _context.SensorReadings.CountAsync(
                    item => item.ObservedAt >= since,
                    cancellationToken),
                sensorDevices,
                onlineSensors
            },
            lots
        });
    }

    [HttpGet("sensors")]
    public async Task<IActionResult> GetSensors(CancellationToken cancellationToken)
    {
        var onlineThreshold = DateTime.UtcNow.AddMinutes(-5);
        var devices = await _context.SensorDevices.AsNoTracking()
            .Include(item => item.ParkingLot)
            .Where(item => !item.IsDeleted)
            .OrderBy(item => item.ParkingLot.Name)
            .ThenBy(item => item.DeviceId)
            .Select(item => new
            {
                item.Id,
                item.DeviceId,
                item.Name,
                item.ParkingLotId,
                ParkingLotName = item.ParkingLot.Name,
                item.IsActive,
                item.LastSeenAt,
                item.BatteryPercent,
                item.FirmwareVersion,
                isOnline = item.IsActive && item.LastSeenAt >= onlineThreshold
            })
            .ToListAsync(cancellationToken);
        return Ok(devices);
    }

    [HttpPost("sensors")]
    public async Task<IActionResult> CreateSensor(
        [FromBody] CreateSensorDeviceRequest request,
        CancellationToken cancellationToken)
    {
        var deviceId = request.DeviceId?.Trim().ToUpperInvariant() ?? string.Empty;
        if (deviceId.Length is < 3 or > 100)
            return BadRequest(new { message = "DeviceId 3-100 karakter olmalıdır." });
        if (!await _context.ParkingLots.AnyAsync(
            item => item.Id == request.ParkingLotId && item.IsActive,
            cancellationToken))
        {
            return NotFound(new { message = "Otopark bulunamadı." });
        }
        if (await _context.SensorDevices.AnyAsync(item => item.DeviceId == deviceId, cancellationToken))
            return Conflict(new { message = "Bu DeviceId zaten kayıtlı." });

        var sensor = new SensorDevice
        {
            DeviceId = deviceId,
            Name = string.IsNullOrWhiteSpace(request.Name) ? deviceId : request.Name.Trim(),
            ParkingLotId = request.ParkingLotId,
            IsActive = true
        };
        _context.SensorDevices.Add(sensor);
        await _context.SaveChangesAsync(cancellationToken);
        return CreatedAtAction(nameof(GetSensors), new { }, sensor);
    }

    [HttpPut("sensors/{id:guid}/status")]
    public async Task<IActionResult> SetSensorStatus(
        Guid id,
        [FromBody] SetStatusRequest request,
        CancellationToken cancellationToken)
    {
        var sensor = await _context.SensorDevices.FirstOrDefaultAsync(
            item => item.Id == id && !item.IsDeleted,
            cancellationToken);
        if (sensor is null)
            return NotFound();
        sensor.IsActive = request.IsActive;
        sensor.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync(cancellationToken);
        return Ok(sensor);
    }

    [HttpPost("parking-lots")]
    public async Task<IActionResult> CreateParkingLot(
        [FromBody] CreateParkingLotRequest request,
        CancellationToken cancellationToken)
    {
        if (request.Capacity is < 1 or > 5000)
            return BadRequest(new { message = "Kapasite 1-5000 arasında olmalıdır." });
        if (request.Latitude is < -90 or > 90 || request.Longitude is < -180 or > 180)
            return BadRequest(new { message = "Geçerli koordinatlar gereklidir." });
        var externalCode = request.ExternalCode?.Trim().ToUpperInvariant() ?? string.Empty;
        if (externalCode.Length is < 2 or > 50)
            return BadRequest(new { message = "ExternalCode 2-50 karakter olmalıdır." });
        if (await _context.ParkingLots.AnyAsync(
            item => item.ExternalCode == externalCode,
            cancellationToken))
        {
            return Conflict(new { message = "ExternalCode zaten kullanılıyor." });
        }

        var lot = new ParkingLot
        {
            Id = Guid.NewGuid(),
            ExternalCode = externalCode,
            Name = request.Name.Trim(),
            Address = request.Address.Trim(),
            Zone = request.Zone.Trim(),
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            TotalCapacity = request.Capacity,
            AvailableCapacity = request.Capacity,
            HourlyRate = request.HourlyRate,
            HasElectricCharging = request.HasElectricCharging,
            HasAccessibleSpaces = request.HasAccessibleSpaces,
            IsCovered = request.IsCovered,
            IsActive = true
        };
        for (var index = 1; index <= request.Capacity; index++)
        {
            lot.Spaces.Add(new ParkingSpace
            {
                Id = Guid.NewGuid(),
                ParkingLotId = lot.Id,
                ParkingLot = lot,
                Code = $"P{index:000}",
                IsElectric = request.HasElectricCharging && index % 10 == 0,
                IsAccessible = request.HasAccessibleSpaces && index % 12 == 0
            });
        }
        _context.ParkingLots.Add(lot);
        await _context.SaveChangesAsync(cancellationToken);
        return Created($"/api/parking/{lot.Id}", new { lot.Id, lot.ExternalCode, lot.Name });
    }
}

public sealed record CreateSensorDeviceRequest(Guid ParkingLotId, string? DeviceId, string? Name);
public sealed record SetStatusRequest(bool IsActive);
public sealed record CreateParkingLotRequest(
    string? ExternalCode,
    string Name,
    string Address,
    string Zone,
    double Latitude,
    double Longitude,
    int Capacity,
    decimal HourlyRate,
    bool HasElectricCharging,
    bool HasAccessibleSpaces,
    bool IsCovered);
