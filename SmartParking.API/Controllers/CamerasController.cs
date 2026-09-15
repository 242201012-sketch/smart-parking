using System.Net.Http.Headers;
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
[Route("api/cameras")]
[AllowAnonymous]
[EnableRateLimiting("sensor")]
public sealed class CamerasController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly IConfiguration _configuration;
    private readonly IHubContext<ParkingHub> _hub;
    private readonly IPushNotificationService _pushNotifications;
    private readonly ITelemetryStore _telemetryStore;
    private readonly IHttpClientFactory _httpClientFactory;

    public CamerasController(
        ApplicationDbContext context,
        IConfiguration configuration,
        IHubContext<ParkingHub> hub,
        IPushNotificationService pushNotifications,
        ITelemetryStore telemetryStore,
        IHttpClientFactory httpClientFactory)
    {
        _context = context;
        _configuration = configuration;
        _hub = hub;
        _pushNotifications = pushNotifications;
        _telemetryStore = telemetryStore;
        _httpClientFactory = httpClientFactory;
    }

    [HttpPost("recognize")]
    [RequestSizeLimit(10_000_000)]
    public async Task<IActionResult> RecognizePlate(
        [FromHeader(Name = "X-Camera-Key")] string? cameraKey,
        IFormFile image,
        [FromForm] Guid? parkingLotId,
        [FromForm] string? cameraId,
        CancellationToken cancellationToken)
    {
        if (!ApiSecurity.FixedTimeEquals(cameraKey, _configuration["Camera:WebhookKey"]))
            return Unauthorized(new { message = "Kamera anahtarı geçersiz." });

        var tensorRtBaseUrl = _configuration["Anpr:TensorRtBaseUrl"];
        if (string.IsNullOrWhiteSpace(tensorRtBaseUrl))
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new { message = "ANPR (TensorRT) servisi yapılandırılmadı." });
        if (image is null || image.Length is <= 0 or > 10_000_000)
            return BadRequest(new { message = "Geçerli bir görüntü gereklidir (maks. 10 MB)." });

        var apiKey = _configuration["Anpr:TensorRtApiKey"];
        using var client = _httpClientFactory.CreateClient("AnprTensorRt");
        client.Timeout = TimeSpan.FromSeconds(30);
        if (!string.IsNullOrWhiteSpace(apiKey))
            client.DefaultRequestHeaders.Authorization =
                new AuthenticationHeaderValue("Bearer", apiKey);

        using var content = new MultipartFormDataContent();
        await using var stream = image.OpenReadStream();
        var fileContent = new StreamContent(stream);
        fileContent.Headers.ContentType = new MediaTypeHeaderValue(
            string.IsNullOrWhiteSpace(image.ContentType) ? "image/jpeg" : image.ContentType);
        content.Add(fileContent, "image", image.FileName);

        HttpResponseMessage response;
        try
        {
            response = await client.PostAsync($"{tensorRtBaseUrl}/api/plates", content, cancellationToken);
        }
        catch (Exception exception)
        {
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new
            {
                message = "ANPR servisine ulaşılamadı.",
                detail = exception.Message
            });
        }

        await using var responseBody = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var document = await JsonDocument.ParseAsync(responseBody, cancellationToken: cancellationToken);
        var root = document.RootElement;

        if (!response.IsSuccessStatusCode)
        {
            var detail = root.TryGetProperty("detail", out var detailElement)
                ? detailElement.GetString()
                : response.ReasonPhrase;
            return StatusCode((int)response.StatusCode, new { message = "ANPR reddetti.", detail });
        }

        var plate = root.TryGetProperty("plate", out var plateElement)
            ? plateElement.GetString()
            : null;
        var confidence = root.TryGetProperty("confidence", out var confidenceElement)
            && confidenceElement.TryGetDecimal(out var confidenceValue)
                ? confidenceValue
                : 0m;

        if (string.IsNullOrWhiteSpace(plate))
            return StatusCode(422, new { message = "Plaka okunamadı.", confidence });

        if (parkingLotId is not null && cameraId is not null)
        {
            var recognized = new AnprEventRequest(
                EventId: $"{cameraId}-{Guid.NewGuid():N}",
                ParkingLotId: parkingLotId.Value,
                CameraId: cameraId,
                PlateNumber: plate,
                Direction: null,
                Confidence: confidence,
                ObservedAt: DateTime.UtcNow);
            await IngestRecognizedEventAsync(recognized, cancellationToken);
        }

        return Ok(new { accepted = true, plate, confidence });
    }

    private async Task IngestRecognizedEventAsync(AnprEventRequest request, CancellationToken cancellationToken)
    {
        // TensorRT tarafından tanınan plakayı anpr-events akışıyla aynı işle
        var direction = request.Direction?.Trim().ToLowerInvariant();
        if (direction is not null && direction is not ("entry" or "exit"))
        {
            direction = null;
        }

        var anprEvent = new AnprEvent
        {
            ExternalEventId = request.EventId.Trim(),
            ParkingLotId = request.ParkingLotId,
            CameraId = request.CameraId.Trim(),
            PlateNumber = request.PlateNumber ?? string.Empty,
            Direction = direction ?? "entry",
            Confidence = request.Confidence,
            ObservedAt = request.ObservedAt?.ToUniversalTime() ?? DateTime.UtcNow
        };
        _context.AnprEvents.Add(anprEvent);
        await _context.SaveChangesAsync(cancellationToken);

        if (_telemetryStore.IsEnabled)
        {
            var _ = _telemetryStore.RecordAnprEventAsync(new AnprEventDocument(
                ExternalEventId: anprEvent.ExternalEventId,
                ParkingLotId: anprEvent.ParkingLotId,
                CameraId: anprEvent.CameraId,
                PlateNumber: anprEvent.PlateNumber,
                Direction: anprEvent.Direction,
                Confidence: anprEvent.Confidence,
                ObservedAt: anprEvent.ObservedAt
            ), cancellationToken);
        }

        await _hub.Clients.All.SendAsync("AnprEventReceived", new
        {
            id = anprEvent.Id,
            parkingLotId = anprEvent.ParkingLotId,
            plateNumber = anprEvent.PlateNumber,
            direction = anprEvent.Direction,
            observedAt = anprEvent.ObservedAt
        }, cancellationToken);
    }

    [HttpPost("anpr-events")]
    public async Task<IActionResult> ReceiveAnprEvent(
        [FromHeader(Name = "X-Camera-Key")] string? cameraKey,
        [FromBody] AnprEventRequest request,
        CancellationToken cancellationToken)
    {
        if (!ApiSecurity.FixedTimeEquals(cameraKey, _configuration["Camera:WebhookKey"]))
            return Unauthorized(new { message = "Kamera anahtarı geçersiz." });
        if (string.IsNullOrWhiteSpace(request.EventId) || string.IsNullOrWhiteSpace(request.CameraId))
            return BadRequest(new { message = "EventId ve CameraId zorunludur." });
        if (request.Confidence is < 0 or > 1)
            return BadRequest(new { message = "Confidence 0-1 arasında olmalıdır." });
        var direction = request.Direction?.Trim().ToLowerInvariant();
        if (direction is not ("entry" or "exit"))
            return BadRequest(new { message = "Direction entry veya exit olmalıdır." });

        var existing = await _context.AnprEvents.AsNoTracking().FirstOrDefaultAsync(
            item => item.ExternalEventId == request.EventId,
            cancellationToken);
        if (existing is not null)
            return Ok(new { accepted = true, duplicate = true, eventId = existing.Id });

        var lot = await _context.ParkingLots.FirstOrDefaultAsync(
            item => item.Id == request.ParkingLotId && item.IsActive,
            cancellationToken);
        if (lot is null)
            return NotFound(new { message = "Otopark bulunamadı." });
        var plate = ApiSecurity.NormalizePlate(request.PlateNumber ?? string.Empty);
        if (plate.Length is < 5 or > 12)
            return BadRequest(new { message = "Geçerli bir plaka gereklidir." });

        var observedAt = request.ObservedAt?.ToUniversalTime() ?? DateTime.UtcNow;
        var anprEvent = new AnprEvent
        {
            ExternalEventId = request.EventId.Trim(),
            ParkingLot = lot,
            ParkingLotId = lot.Id,
            CameraId = request.CameraId.Trim(),
            PlateNumber = plate,
            Direction = direction,
            Confidence = request.Confidence,
            ObservedAt = observedAt
        };
        _context.AnprEvents.Add(anprEvent);

        var vehicle = await _context.Vehicles.AsNoTracking()
            .OrderByDescending(item => item.UpdatedAt ?? item.CreatedAt)
            .FirstOrDefaultAsync(
                item => item.PlateNumber == plate && !item.IsDeleted,
                cancellationToken);
        string? pushTitle = null;
        string? pushBody = null;
        if (vehicle is not null)
        {
            if (direction == "entry")
            {
                var hasActiveSession = await _context.ParkingSessions.AnyAsync(
                    item => item.UserId == vehicle.UserId && item.EndedAt == null && !item.IsDeleted,
                    cancellationToken);
                if (!hasActiveSession)
                {
                    _context.ParkingSessions.Add(new ParkingSession
                    {
                        UserId = vehicle.UserId,
                        ParkingLot = lot,
                        ParkingLotId = lot.Id,
                        VehiclePlate = plate,
                        StartedAt = observedAt
                    });
                    _context.UserNotifications.Add(new UserNotification
                    {
                        UserId = vehicle.UserId,
                        Type = "parking",
                        Title = "Plakanız tanındı",
                        Message = $"{lot.Name} girişiniz otomatik kaydedildi."
                    });
                    pushTitle = "Plakanız tanındı";
                    pushBody = $"{lot.Name} girişiniz otomatik kaydedildi.";
                }
            }
            else
            {
                var session = await _context.ParkingSessions
                    .Include(item => item.ParkingLot)
                    .FirstOrDefaultAsync(
                        item => item.UserId == vehicle.UserId
                            && item.ParkingLotId == lot.Id
                            && item.VehiclePlate == plate
                            && item.EndedAt == null
                            && !item.IsDeleted,
                        cancellationToken);
                if (session is not null)
                {
                    session.EndedAt = observedAt;
                    var minutes = Math.Max(1, (decimal)(observedAt - session.StartedAt).TotalMinutes);
                    session.TotalAmount = Math.Round(lot.HourlyRate * minutes / 60m, 2);
                    session.UpdatedAt = DateTime.UtcNow;
                    _context.UserNotifications.Add(new UserNotification
                    {
                        UserId = vehicle.UserId,
                        Type = "payment",
                        Title = "Otopark çıkışı kaydedildi",
                        Message = $"Ödenecek tutar {session.TotalAmount:0.00} TL."
                    });
                    pushTitle = "Otopark çıkışı kaydedildi";
                    pushBody = $"Ödenecek tutar {session.TotalAmount:0.00} TL.";
                }
            }
        }

        await _context.SaveChangesAsync(cancellationToken);

        if (_telemetryStore.IsEnabled)
        {
            var _ = _telemetryStore.RecordAnprEventAsync(new AnprEventDocument(
                ExternalEventId: request.EventId.Trim(),
                ParkingLotId: lot.Id,
                CameraId: request.CameraId.Trim(),
                PlateNumber: plate,
                Direction: direction,
                Confidence: request.Confidence,
                ObservedAt: observedAt
            ), cancellationToken);
        }

        await _hub.Clients.All.SendAsync("AnprEventReceived", new
        {
            id = anprEvent.Id,
            parkingLotId = lot.Id,
            plateNumber = plate,
            direction,
            observedAt
        }, cancellationToken);
        if (vehicle is not null && pushTitle is not null && pushBody is not null)
        {
            await _pushNotifications.SendToUserAsync(
                vehicle.UserId,
                pushTitle,
                pushBody,
                new Dictionary<string, string> { ["screen"] = "profile" },
                cancellationToken);
        }
        return Accepted(new { accepted = true, duplicate = false, eventId = anprEvent.Id });
    }
}

public sealed record AnprEventRequest(
    string EventId,
    Guid ParkingLotId,
    string CameraId,
    string? PlateNumber,
    string? Direction,
    decimal Confidence,
    DateTime? ObservedAt);
