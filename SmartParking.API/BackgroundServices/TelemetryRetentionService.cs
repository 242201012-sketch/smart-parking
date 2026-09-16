using Microsoft.Extensions.Options;
using SmartParking.Application.Interfaces;
using SmartParking.Infrastructure.Telemetry;

namespace SmartParking.API.BackgroundServices;

/// <summary>
/// MongoDB telemetri deposunda retention sürelerini aşan ham kayıtları
/// periyodik olarak siler. Telemetri yapılandırılmadıysa (NoOp) atlar.
/// Aralığı <c>DocumentDb:RetentionIntervalHours</c> belirler (en az 1 saat).
/// </summary>
public sealed class TelemetryRetentionService : BackgroundService
{
    private readonly ITelemetryStore _telemetryStore;
    private readonly IOptions<MongoTelemetryStoreOptions> _options;
    private readonly ILogger<TelemetryRetentionService> _logger;

    public TelemetryRetentionService(
        ITelemetryStore telemetryStore,
        IOptions<MongoTelemetryStoreOptions> options,
        ILogger<TelemetryRetentionService> logger)
    {
        _telemetryStore = telemetryStore;
        _options = options;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                if (_telemetryStore.IsEnabled)
                {
                    var result = await _telemetryStore.PurgeExpiredAsync(
                        DateTime.UtcNow, stoppingToken);
                    _logger.LogInformation(
                        "Telemetri retention tamamlandı: {SensorCount} sensör, {AnprCount} ANPR kaydı silindi.",
                        result.DeletedSensorReadings,
                        result.DeletedAnprEvents);
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "Telemetri retention temizliği başarısız.");
            }

            await Task.Delay(Interval, stoppingToken);
        }
    }

    private TimeSpan Interval =>
        TimeSpan.FromHours(Math.Max(1, _options.Value.RetentionIntervalHours));
}
