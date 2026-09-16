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
/// Aynı sensör uzayı (spaceCode) için depoda biriken okumaların tek Mongo
/// kaydında birleştirilmiş (coalesced) görünümü.
/// </summary>
public sealed record CoalescedSensorSpaceView(
    Guid ParkingLotId,
    Guid ParkingSpaceId,
    string SpaceCode,
    int ReadingCount,
    DateTime FirstObservedAtUtc,
    DateTime LastObservedAtUtc,
    bool IsOccupied,
    int? BatteryPercent,
    string? VehiclePlate,
    string? DeviceId);

/// <summary>ANPR giriş/çıkış akışında tek bir zaman dilimi (60 dk) noktası.</summary>
public sealed record AnprTrendPoint(
    DateTime BucketStartUtc,
    int Entries,
    int Exits);

/// <summary>Bir otopark için anlık kapasite/doluluk özeti.</summary>
public sealed record ParkingLotCapacitySnapshot(
    Guid ParkingLotId,
    string? LotName,
    int TotalSpaces,
    int OccupiedSpaces,
    int AvailableSpaces,
    DateTime AsOfUtc);

/// <summary>
/// Yüksek hacimli sensör/ANPR ham verilerinin MongoDB (AWS DocumentDB uyumlu)
/// tarafına yazılmasını sağlayan uç. Mongo yapılandırılmadıysa işlem atlanır ve
/// mevcut ilişkisel (EF Core) depolama tek kaynak olarak çalışmaya devam eder.
/// </summary>
public interface ITelemetryStore
{
    bool IsEnabled { get; }

    /// <summary>Belirli bir otoparka ait bir sensör okumasını depoya yazar.</summary>
    Task RecordSensorReadingAsync(
        SensorReadingDocument reading,
        CancellationToken cancellationToken);

    /// <summary>Belirli bir otoparka ait bir ANPR olayını depoya yazar.</summary>
    Task RecordAnprEventAsync(
        AnprEventDocument evt,
        CancellationToken cancellationToken);

    /// <summary>
    /// Belirli bir otoparka ait sensör okumalarının birleştirilmiş (coalesced)
    /// görünümünü döndürür: uzay başına tek kayıt, içinde kaç raw okuma, aralık,
    /// batarya ortalaması, son plaka ve doluluk.
    /// </summary>
    Task<IReadOnlyList<CoalescedSensorSpaceView>> GetCoalescedSensorSpaceViewsAsync(
        Guid parkingLotId,
        CancellationToken cancellationToken);

    /// <summary>
    /// ANPR giriş/çıkış olaylarını 60 dakikalık kovalar (bucket) hâlinde gruplayarak
    /// bir zaman aralığında entry/exit trendini döndürür.
    /// </summary>
    Task<IReadOnlyList<AnprTrendPoint>> GetAnprTrendAsync(
        Guid parkingLotId,
        DateTime fromUtc,
        DateTime toUtc,
        CancellationToken cancellationToken);

    /// <summary>
    /// Bir otopark için anlık kapasite/doluluk anlık görüntüsü (Mongo'da biriken
    /// sensör durumundan hesaplanır).
    /// </summary>
    Task<ParkingLotCapacitySnapshot?> GetParkingLotCapacityAsync(
        Guid parkingLotId,
        CancellationToken cancellationToken);
}
