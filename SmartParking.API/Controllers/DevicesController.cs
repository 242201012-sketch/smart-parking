using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartParking.API.Security;
using SmartParking.Application.Interfaces;
using SmartParking.Domain.Entities;
using SmartParking.Infrastructure.Persistence;

namespace SmartParking.API.Controllers;

[ApiController]
[Route("api/devices")]
[Authorize]
public sealed class DevicesController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly IPushNotificationService _pushNotifications;

    public DevicesController(
        ApplicationDbContext context,
        IPushNotificationService pushNotifications)
    {
        _context = context;
        _pushNotifications = pushNotifications;
    }

    [HttpGet("push/status")]
    public async Task<IActionResult> GetPushStatus(CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var registeredDevices = await _context.PushDevices.CountAsync(
            device => device.UserId == userId && device.IsActive && !device.IsDeleted,
            cancellationToken);
        return Ok(new
        {
            enabled = _pushNotifications.IsEnabled,
            registeredDevices
        });
    }

    [HttpPost("push")]
    public async Task<IActionResult> RegisterPushDevice(
        [FromBody] RegisterPushDeviceRequest request,
        CancellationToken cancellationToken)
    {
        var token = request.Token?.Trim() ?? string.Empty;
        if (token.Length is < 20 or > 4096)
            return BadRequest(new { message = "FCM cihaz tokenı geçersiz." });

        var platform = request.Platform?.Trim().ToLowerInvariant() ?? "android";
        if (platform is not ("android" or "ios" or "web"))
            return BadRequest(new { message = "Platform android, ios veya web olmalıdır." });

        var userId = User.GetUserId();
        var now = DateTime.UtcNow;
        var deviceName = TrimToLength(request.DeviceName, 160);
        var tokenHash = HashToken(token);
        var device = await _context.PushDevices.FirstOrDefaultAsync(
            item => item.TokenHash == tokenHash,
            cancellationToken);
        if (device is null)
        {
            device = new PushDevice
            {
                UserId = userId,
                Token = token,
                TokenHash = tokenHash,
                Platform = platform,
                DeviceName = deviceName,
                IsActive = true,
                LastSeenAt = now
            };
            _context.PushDevices.Add(device);
        }
        else
        {
            device.UserId = userId;
            device.Token = token;
            device.TokenHash = tokenHash;
            device.Platform = platform;
            device.DeviceName = deviceName;
            device.IsActive = true;
            device.IsDeleted = false;
            device.LastSeenAt = now;
            device.UpdatedAt = now;
        }

        await _context.SaveChangesAsync(cancellationToken);
        return Ok(new
        {
            registered = true,
            pushEnabled = _pushNotifications.IsEnabled,
            deviceId = device.Id
        });
    }

    [HttpDelete("push")]
    public async Task<IActionResult> UnregisterPushDevice(
        [FromBody] UnregisterPushDeviceRequest request,
        CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var token = request.Token?.Trim() ?? string.Empty;
        if (token.Length is < 20 or > 4096) return NoContent();
        var tokenHash = HashToken(token);
        var device = await _context.PushDevices.FirstOrDefaultAsync(
            item => item.UserId == userId && item.TokenHash == tokenHash,
            cancellationToken);
        if (device is null) return NoContent();

        device.IsActive = false;
        device.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    private static string TrimToLength(string? value, int maxLength)
    {
        var normalized = value?.Trim() ?? string.Empty;
        return normalized.Length <= maxLength
            ? normalized
            : normalized[..maxLength];
    }

    private static string HashToken(string token) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
}

public sealed record RegisterPushDeviceRequest(
    string? Token,
    string? Platform,
    string? DeviceName);

public sealed record UnregisterPushDeviceRequest(string? Token);
