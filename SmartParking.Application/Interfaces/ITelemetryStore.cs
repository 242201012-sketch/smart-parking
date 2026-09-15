namespace SmartParking.Application.Interfaces;

/// <summary>MongoDB/DocumentDB telemetri deposuna yazılan bir sensör okuması.</summary>
public sealed record SensorReadingDocument(
    string DeviceId,
    long Sequence,
    Guid ParkingLotId,
    Guid ParkingSpaceId,
    string SpaceCode,
    bool IsOccupied,
    DateTime ObservedAt,
    int? BatteryPercent,
    string? VehiclePlate,
    string? MetadataJson);

/// <summary>MongoDB/DocumentDB telemetri deposuna yazılan bir ANPR olayı.</summary>
public sealed record AnprEventDocument(
    string ExternalEventId,
    Guid ParkingLotId,
    string CameraId,
    string PlateNumber,
    string Direction,
    decimal Confidence,
    DateTime ObservedAt);

/// <summary>
/// Yüksek hacimli sensör/ANPR ham verilerinin MongoDB (AWS DocumentDB uyumlu)
/// tarafına yazılmasını sağlayan uç. Mongo yapılandırılmadıysa işlem atlanır ve
/// mevcut ilişkisel (EF Core) depolama tek kaynak olarak çalışmaya devam eder.
/// </summary>
public interface ITelemetryStore
{
    bool IsEnabled { get; }

    Task RecordSensorReadingAsync(SensorReadingDocument reading, CancellationToken cancellationToken);

    Task RecordAnprEventAsync(AnprEventDocument evt, CancellationToken cancellationToken);
}