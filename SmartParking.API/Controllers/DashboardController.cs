using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartParking.Application.Interfaces;

namespace SmartParking.API.Controllers;

/// <summary>
/// Telemetri deposundan (DocumentDB/MongoDB) okunan dashboard verileri:
/// birleştirilmiş sensör görünümü, ANPR giriş/çıkış trendi ve kapasite özeti.
/// Telemetri deposu yapılandırılmadıysa her endpoint boş/200 döner (5733'te graceful).
/// </summary>
[ApiController]
[Route("api/dashboard")]
[Authorize]
[Produces("application/json")]
public sealed class DashboardController : ControllerBase
{
    private readonly ITelemetryStore _telemetryStore;

    public DashboardController(ITelemetryStore telemetryStore)
    {
        _telemetryStore = telemetryStore;
    }

    /// <summary>
    /// GET api/dashboard/{parkingLotId}/coalesced-sensor-spaces
    /// Aynı uzay kodu için depoda biriken sensör okumalarının birleştirilmiş görünümü.
    /// </summary>
    [HttpGet("{parkingLotId:guid}/coalesced-sensor-spaces")]
    [ProducesResponseType(typeof(IReadOnlyList<CoalescedSensorSpaceView>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GetCoalescedSensorSpaces(
        Guid parkingLotId,
        CancellationToken cancellationToken)
    {
        var views = await _telemetryStore.GetCoalescedSensorSpaceViewsAsync(
            parkingLotId, cancellationToken);
        return Ok(views);
    }

    /// <summary>
    /// GET api/dashboard/{parkingLotId}/anpr-trend?fromUtc=...&amp;toUtc=...
    /// ANPR giriş/çıkış olaylarını 60 dakikalık kovalara bölerek entry/exit trendi.
    /// </summary>
    [HttpGet("{parkingLotId:guid}/anpr-trend")]
    [ProducesResponseType(typeof(IReadOnlyList<AnprTrendPoint>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GetAnprTrend(
        Guid parkingLotId,
        [FromQuery] DateTime? fromUtc,
        [FromQuery] DateTime? toUtc,
        CancellationToken cancellationToken)
    {
        var to = (toUtc ?? DateTime.UtcNow).ToUniversalTime();
        var from = (fromUtc ?? to.AddHours(-24)).ToUniversalTime();
        if (from >= to)
            return BadRequest(new { message = "fromUtc, toUtc'den önce olmalıdır." });

        var points = await _telemetryStore.GetAnprTrendAsync(
            parkingLotId, from, to, cancellationToken);
        return Ok(points);
    }

    /// <summary>
    /// GET api/dashboard/{parkingLotId}/capacity
    /// Otoparkın anlık kapasite/doluluk özeti (sensör okumalarından hesaplanır).
    /// </summary>
    [HttpGet("{parkingLotId:guid}/capacity")]
    [ProducesResponseType(typeof(ParkingLotCapacitySnapshot), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GetCapacity(
        Guid parkingLotId,
        CancellationToken cancellationToken)
    {
        var snapshot = await _telemetryStore.GetParkingLotCapacityAsync(
            parkingLotId, cancellationToken);
        return snapshot is null
            ? NotFound(new { parkingLotId, message = "Kapasite verisi bulunamadı." })
            : Ok(snapshot);
    }
}
