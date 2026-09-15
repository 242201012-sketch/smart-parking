using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using SmartParking.API.Hubs;
using SmartParking.API.Security;
using SmartParking.Application.Interfaces;
using SmartParking.Domain.Entities;
using SmartParking.Infrastructure.Persistence;

namespace SmartParking.API.Controllers;

[ApiController]
[Route("api/sensors")]
[AllowAnonymous]
[EnableRateLimiting("sensor")]
public sealed class SensorsController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly IConfiguration _configuration;
    private readonly IHubContext<ParkingHub> _hub;
    private readonly ITelemetryStore _telemetryStore;

    public SensorsController(
        ApplicationDbContext context,
        IConfiguration configuration,
        IHubContext<ParkingHub> hub,
        ITelemetryStore telemetryStore)
    {
        _context = context;
        _configuration = configuration;
        _hub = hub;
        _telemetryStore = telemetryStore;
    }

    [HttpPost("readings")]
    public async Task<IActionResult> IngestReading(
        [FromHeader(Name = "X-Device-Id")] string? deviceId,
        [FromHeader(Name = "X-Sensor-Key")] string? sensorKey,
        [FromBody] SensorReadingRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsAuthorized(sensorKey))
            return Unauthorized(new { message = "Sensör anahtarı geçersiz." });
        if (string.IsNullOrWhiteSpace(deviceId) || deviceId.Length > 100)
            return BadRequest(new { message = "X-Device-Id başlığı gereklidir." });
        if (request.Sequence <= 0 || string.IsNullOrWhiteSpace(request.SpaceCode))
            return BadRequest(new { message = "Sequence ve SpaceCode zorunludur." });
        if (request.BatteryPercent is < 0 or > 100)
            return BadRequest(new { message = "BatteryPercent 0-100 arasında olmalıdır." });

        var now = DateTime.UtcNow;
        var observedAt = NormalizeUtc(request.ObservedAt ?? now);
        if (observedAt > now.AddMinutes(5) || observedAt < now.AddDays(-7))
            return BadRequest(new { message = "ObservedAt kabul edilen zaman aralığının dışında." });

        deviceId = deviceId.Trim();
        var duplicate = await _context.SensorReadings
            .AsNoTracking()
            .FirstOrDefaultAsync(
                item => item.DeviceId == deviceId && item.Sequence == request.Sequence,
                cancellationToken);
        if (duplicate is not null)
        {
            return Ok(new
            {
                accepted = true,
                duplicate = true,
                readingId = duplicate.Id,
                duplicate.ObservedAt
            });
        }

        var device = await _context.SensorDevices
            .Include(item => item.ParkingLot)
            .FirstOrDefaultAsync(item => item.DeviceId == deviceId, cancellationToken);
        if (device is null || !device.IsActive)
            return Unauthorized(new { message = "Sensör cihazı kayıtlı veya aktif değil." });

        if (request.ParkingLotId is not null && request.ParkingLotId != device.ParkingLotId)
            return BadRequest(new { message = "Cihaz farklı bir otoparka veri gönderemez." });
        if (!string.IsNullOrWhiteSpace(request.ParkingLotCode)
            && !request.ParkingLotCode.Equals(device.ParkingLot.ExternalCode, StringComparison.OrdinalIgnoreCase))
        {
            return BadRequest(new { message = "ParkingLotCode cihaz kaydıyla eşleşmiyor." });
        }

        var normalizedSpaceCode = request.SpaceCode.Trim().ToUpperInvariant();
        var space = await _context.ParkingSpaces.FirstOrDefaultAsync(
            item => item.ParkingLotId == device.ParkingLotId && item.Code == normalizedSpaceCode,
            cancellationToken);
        if (space is null)
            return NotFound(new { message = "Park alanı bulunamadı." });

        await using var transaction = await _context.Database.BeginTransactionAsync(cancellationToken);
        var plate = string.IsNullOrWhiteSpace(request.VehiclePlate)
            ? null
            : ApiSecurity.NormalizePlate(request.VehiclePlate);

        space.IsOccupied = request.IsOccupied;
        space.VehiclePlate = request.IsOccupied ? plate : null;
        space.LastOccupiedAt = request.IsOccupied ? observedAt : space.LastOccupiedAt;
        space.UpdatedAt = now;
        device.LastSeenAt = now;
        device.BatteryPercent = request.BatteryPercent;
        device.FirmwareVersion = request.FirmwareVersion?.Trim();
        device.UpdatedAt = now;

        var reading = new SensorReading
        {
            DeviceId = deviceId,
            Sequence = request.Sequence,
            ParkingLotId = device.ParkingLotId,
            ParkingSpaceId = space.Id,
            ParkingSpace = space,
            IsOccupied = request.IsOccupied,
            ObservedAt = observedAt,
            BatteryPercent = request.BatteryPercent,
            VehiclePlate = plate,
            MetadataJson = request.Metadata is null
                ? null
                : JsonSerializer.Serialize(request.Metadata)
        };
        _context.SensorReadings.Add(reading);
        await _context.SaveChangesAsync(cancellationToken);

        var total = await _context.ParkingSpaces.CountAsync(
            item => item.ParkingLotId == device.ParkingLotId,
            cancellationToken);
        var available = await _context.ParkingSpaces.CountAsync(
            item => item.ParkingLotId == device.ParkingLotId
                && !item.IsOccupied
                && (!item.IsReserved || item.ReservedUntil <= now),
            cancellationToken);
        device.ParkingLot.TotalCapacity = total;
        device.ParkingLot.AvailableCapacity = available;
        device.ParkingLot.UpdatedAt = now;
        await _context.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        if (_telemetryStore.IsEnabled)
        {
            var _ = _telemetryStore.RecordSensorReadingAsync(new SensorReadingDocument(
                DeviceId: deviceId,
                Sequence: request.Sequence,
                ParkingLotId: device.ParkingLotId,
                ParkingSpaceId: space.Id,
                SpaceCode: normalizedSpaceCode,
                IsOccupied: request.IsOccupied,
                ObservedAt: observedAt,
                BatteryPercent: request.BatteryPercent,
                VehiclePlate: plate,
                MetadataJson: request.Metadata is null ? null : System.Text.Json.JsonSerializer.Serialize(request.Metadata)
            ), cancellationToken);
        }

        var update = new
        {
            parkingLotId = device.ParkingLotId.ToString(),
            parkingSpaceId = space.Id.ToString(),
            spaceCode = space.Code,
            isOccupied = space.IsOccupied,
            isReserved = space.IsReserved && space.ReservedUntil > now,
            availableCapacity = available,
            totalCapacity = total,
            updatedAt = now
        };
        await _hub.Clients.All.SendAsync("ParkingSpaceUpdated", update, cancellationToken);
        await _hub.Clients.All.SendAsync(
            "ParkingStatusUpdated",
            device.ParkingLotId.ToString(),
            available > 0,
            cancellationToken);
        await _hub.Clients.All.SendAsync("ParkingLotUpdated", new
        {
            id = device.ParkingLotId.ToString(),
            device.ParkingLot.Name,
            device.ParkingLot.Address,
            device.ParkingLot.Latitude,
            device.ParkingLot.Longitude,
            totalCapacity = total,
            availableCapacity = available,
            device.ParkingLot.Zone,
            device.ParkingLot.HourlyRate,
            device.ParkingLot.HasElectricCharging,
            device.ParkingLot.HasAccessibleSpaces,
            device.ParkingLot.IsCovered,
            updatedAt = now
        }, cancellationToken);

        return Accepted(new
        {
            accepted = true,
            duplicate = false,
            readingId = reading.Id,
            serverTime = now,
            parkingLotId = device.ParkingLotId,
            spaceId = space.Id,
            availableCapacity = available
        });
    }

    [HttpPost("heartbeat")]
    public async Task<IActionResult> Heartbeat(
        [FromHeader(Name = "X-Device-Id")] string? deviceId,
        [FromHeader(Name = "X-Sensor-Key")] string? sensorKey,
        [FromBody] SensorHeartbeatRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsAuthorized(sensorKey))
            return Unauthorized(new { message = "Sensör anahtarı geçersiz." });
        if (string.IsNullOrWhiteSpace(deviceId))
            return BadRequest(new { message = "X-Device-Id başlığı gereklidir." });
        if (request.BatteryPercent is < 0 or > 100)
            return BadRequest(new { message = "BatteryPercent 0-100 arasında olmalıdır." });

        var device = await _context.SensorDevices.FirstOrDefaultAsync(
            item => item.DeviceId == deviceId.Trim() && item.IsActive,
            cancellationToken);
        if (device is null)
            return Unauthorized(new { message = "Sensör cihazı kayıtlı veya aktif değil." });

        device.LastSeenAt = DateTime.UtcNow;
        device.BatteryPercent = request.BatteryPercent;
        device.FirmwareVersion = request.FirmwareVersion?.Trim();
        device.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync(cancellationToken);
        return Ok(new { accepted = true, serverTime = DateTime.UtcNow });
    }

    private bool IsAuthorized(string? key) => ApiSecurity.FixedTimeEquals(
        key,
        _configuration["Sensor:IngestKey"]);

    private static DateTime NormalizeUtc(DateTime value) => value.Kind switch
    {
        DateTimeKind.Utc => value,
        DateTimeKind.Local => value.ToUniversalTime(),
        _ => DateTime.SpecifyKind(value, DateTimeKind.Utc)
    };
}

public sealed record SensorReadingRequest(
    Guid? ParkingLotId,
    string? ParkingLotCode,
    string SpaceCode,
    bool IsOccupied,
    long Sequence,
    DateTime? ObservedAt,
    int? BatteryPercent,
    string? VehiclePlate,
    string? FirmwareVersion,
    Dictionary<string, JsonElement>? Metadata);

public sealed record SensorHeartbeatRequest(
    int? BatteryPercent,
    string? FirmwareVersion);
