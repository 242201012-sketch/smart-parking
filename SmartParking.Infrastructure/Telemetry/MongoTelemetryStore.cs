using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using MongoDB.Driver;
using SmartParking.Application.Interfaces;

namespace SmartParking.Infrastructure.Telemetry;

/// <summary>MongoDB (AWS DocumentDB uyumlu) telemetri deposu seçenekleri.</summary>
public sealed class MongoTelemetryStoreOptions
{
    public string? ConnectionString { get; set; }
    public string DatabaseName { get; set; } = "smartparking-telemetry";
    public int SensorReadingsRetentionDays { get; set; } = 365;
    public int AnprRetentionDays { get; set; } = 730;
    public int RetentionIntervalHours { get; set; } = 24;
}

/// <summary>
/// Yüksek hacimli sensör/ANPR ham verilerinin MongoDB (AWS DocumentDB uyumlu)
/// tarafına yazılmasını ve dashboard için birleştirilmiş raporların okunmasını
/// sağlayan uç. Mongo yapılandırılmadıysa <see cref="NoOpTelemetryStore"/>
/// kullanılır ve mevcut ilişkisel (EF Core) depolama tek kaynak olarak çalışır.
/// </summary>
public sealed class MongoTelemetryStore : ITelemetryStore
{
    private readonly IMongoDatabase _database;
    private readonly MongoTelemetryStoreOptions _options;
    private readonly ILogger<MongoTelemetryStore> _logger;

    public MongoTelemetryStore(
        IOptions<MongoTelemetryStoreOptions> options,
        ILogger<MongoTelemetryStore> logger)
    {
        _logger = logger;
        var value = options.Value;
        _options = value;
        var client = new MongoClient(value.ConnectionString);
        _database = client.GetDatabase(value.DatabaseName);
    }

    public bool IsEnabled => true;

    public async Task RecordSensorReadingAsync(
        SensorReadingDocument reading,
        CancellationToken cancellationToken)
    {
        var collection = _database.GetCollection<SensorReadingBson>("SensorReadings");
        await EnsureSensorReadingIndexesAsync(collection, cancellationToken);
        await collection.InsertOneAsync(
            SensorReadingBson.From(reading),
            cancellationToken: cancellationToken);
    }

    public async Task RecordAnprEventAsync(
        AnprEventDocument evt,
        CancellationToken cancellationToken)
    {
        var collection = _database.GetCollection<AnprEventBson>("AnprEvents");
        await EnsureAnprIndexesAsync(collection, cancellationToken);
        await collection.InsertOneAsync(
            AnprEventBson.From(evt),
            cancellationToken: cancellationToken);
    }

    public async Task<IReadOnlyList<CoalescedSensorSpaceView>> GetCoalescedSensorSpaceViewsAsync(
        Guid parkingLotId,
        CancellationToken cancellationToken)
    {
        var collection = _database.GetCollection<SensorReadingBson>("SensorReadings");
        var filter = Builders<SensorReadingBson>.Filter.Eq(
            item => item.ParkingLotId, parkingLotId.ToString());
        using var cursor = await collection.FindAsync(filter, cancellationToken: cancellationToken);
        var documents = await cursor.ToListAsync(cancellationToken);

        return documents
            .GroupBy(item => item.SpaceCode)
            .Select(group =>
            {
                var ordered = group.OrderBy(item => item.ObservedAt).ToList();
                var latest = ordered[^1];
                var averageBattery = group
                    .Select(item => item.BatteryPercent)
                    .Where(battery => battery.HasValue)
                    .DefaultIfEmpty()
                    .Average(battery => battery ?? 0);

                return new CoalescedSensorSpaceView(
                    parkingLotId,
                    Guid.Parse(ordered[0].ParkingSpaceId),
                    group.Key,
                    group.Count(),
                    ordered[0].ObservedAt,
                    latest.ObservedAt,
                    latest.IsOccupied,
                    averageBattery == 0 ? null : (int)Math.Round(averageBattery),
                    latest.VehiclePlate,
                    latest.DeviceId);

            })
            .OrderBy(view => view.SpaceCode)
            .ToList();
    }

    public async Task<IReadOnlyList<AnprTrendPoint>> GetAnprTrendAsync(
        Guid parkingLotId,
        DateTime fromUtc,
        DateTime toUtc,
        CancellationToken cancellationToken)
    {
        var collection = _database.GetCollection<AnprEventBson>("AnprEvents");
        var filter = Builders<AnprEventBson>.Filter.And(
            Builders<AnprEventBson>.Filter.Eq(
                item => item.ParkingLotId, parkingLotId.ToString()),
            Builders<AnprEventBson>.Filter.Gte(item => item.ObservedAt, fromUtc),
            Builders<AnprEventBson>.Filter.Lt(item => item.ObservedAt, toUtc));
        using var cursor = await collection.FindAsync(filter, cancellationToken: cancellationToken);
        var documents = await cursor.ToListAsync(cancellationToken);

        return documents
            .GroupBy(item => new DateTime(
                item.ObservedAt.Year,
                item.ObservedAt.Month,
                item.ObservedAt.Day,
                item.ObservedAt.Hour,
                0,
                0,
                DateTimeKind.Utc))
            .Select(group => new AnprTrendPoint(
                group.Key,
                group.Count(item => item.Direction.Equals("entry", StringComparison.OrdinalIgnoreCase)),
                group.Count(item => item.Direction.Equals("exit", StringComparison.OrdinalIgnoreCase))))
            .OrderBy(point => point.BucketStartUtc)
            .ToList();
    }

    public async Task<ParkingLotCapacitySnapshot?> GetParkingLotCapacityAsync(
        Guid parkingLotId,
        CancellationToken cancellationToken)
    {
        var collection = _database.GetCollection<SensorReadingBson>("SensorReadings");
        var filter = Builders<SensorReadingBson>.Filter.Eq(
            item => item.ParkingLotId, parkingLotId.ToString());
        using var cursor = await collection.FindAsync(filter, cancellationToken: cancellationToken);
        var documents = await cursor.ToListAsync(cancellationToken);

        var latestBySpace = documents
            .GroupBy(item => item.SpaceCode)
            .Select(group => group.OrderByDescending(item => item.ObservedAt).First())
            .ToList();

        var occupiedSpaces = latestBySpace.Count(item => item.IsOccupied);

        return new ParkingLotCapacitySnapshot(
            parkingLotId,
            null,
            latestBySpace.Count,
            occupiedSpaces,
            latestBySpace.Count - occupiedSpaces,
            DateTime.UtcNow);
    }

    public async Task<TelemetryPurgeResult> PurgeExpiredAsync(
        DateTime utcNow,
        CancellationToken cancellationToken)
    {
        var sensorCutoff = utcNow.AddDays(-_options.SensorReadingsRetentionDays);
        var anprCutoff = utcNow.AddDays(-_options.AnprRetentionDays);

        var sensorCollection = _database.GetCollection<SensorReadingBson>("SensorReadings");
        var sensorResult = await sensorCollection.DeleteManyAsync(
            Builders<SensorReadingBson>.Filter.Lt(item => item.ObservedAt, sensorCutoff),
            cancellationToken);

        var anprCollection = _database.GetCollection<AnprEventBson>("AnprEvents");
        var anprResult = await anprCollection.DeleteManyAsync(
            Builders<AnprEventBson>.Filter.Lt(item => item.ObservedAt, anprCutoff),
            cancellationToken);

        var result = new TelemetryPurgeResult(
            (int)sensorResult.DeletedCount,
            (int)anprResult.DeletedCount);
        _logger.LogInformation(
            "Telemetri retention temizliği: {SensorCount} sensör okuması, {AnprCount} ANPR olayı silindi.",
            result.DeletedSensorReadings,
            result.DeletedAnprEvents);
        return result;
    }

    private async Task EnsureSensorReadingIndexesAsync(
        IMongoCollection<SensorReadingBson> collection,
        CancellationToken cancellationToken)
    {
        await collection.Indexes.CreateOneAsync(
            new CreateIndexModel<SensorReadingBson>(
                Builders<SensorReadingBson>.IndexKeys
                    .Ascending(item => item.DeviceId)
                    .Ascending(item => item.Sequence),
                new CreateIndexOptions { Unique = true }),
            cancellationToken: cancellationToken);
        await collection.Indexes.CreateOneAsync(
            new CreateIndexModel<SensorReadingBson>(
                Builders<SensorReadingBson>.IndexKeys.Ascending(item => item.ObservedAt),
                new CreateIndexOptions
                {
                    ExpireAfter = TimeSpan.FromDays(365)
                }),
            cancellationToken: cancellationToken);
    }

    private async Task EnsureAnprIndexesAsync(
        IMongoCollection<AnprEventBson> collection,
        CancellationToken cancellationToken)
    {
        await collection.Indexes.CreateOneAsync(
            new CreateIndexModel<AnprEventBson>(
                Builders<AnprEventBson>.IndexKeys.Ascending(item => item.ExternalEventId),
                new CreateIndexOptions { Unique = true }),
            cancellationToken: cancellationToken);
        await collection.Indexes.CreateOneAsync(
            new CreateIndexModel<AnprEventBson>(
                Builders<AnprEventBson>.IndexKeys.Ascending(item => item.ObservedAt),
                new CreateIndexOptions
                {
                    ExpireAfter = TimeSpan.FromDays(730)
                }),
            cancellationToken: cancellationToken);
    }

    private sealed class SensorReadingBson
    {
        [BsonId]
        public ObjectId Id { get; set; }

        [BsonElement("device_id")]
        public string DeviceId { get; set; } = string.Empty;

        [BsonElement("sequence")]
        public long Sequence { get; set; }

        [BsonElement("parking_lot_id")]
        public string ParkingLotId { get; set; } = string.Empty;

        [BsonElement("parking_space_id")]
        public string ParkingSpaceId { get; set; } = string.Empty;

        [BsonElement("space_code")]
        public string SpaceCode { get; set; } = string.Empty;

        [BsonElement("is_occupied")]
        public bool IsOccupied { get; set; }

        [BsonElement("observed_at")]
        public DateTime ObservedAt { get; set; }

        [BsonElement("battery_percent")]
        public int? BatteryPercent { get; set; }

        [BsonElement("vehicle_plate")]
        public string? VehiclePlate { get; set; }

        public static SensorReadingBson From(SensorReadingDocument source) => new()
        {
            DeviceId = source.DeviceId,
            Sequence = source.Sequence,
            ParkingLotId = source.ParkingLotId.ToString(),
            ParkingSpaceId = source.ParkingSpaceId.ToString(),
            SpaceCode = source.SpaceCode,
            IsOccupied = source.IsOccupied,
            ObservedAt = source.ObservedAt,
            BatteryPercent = source.BatteryPercent,
            VehiclePlate = source.VehiclePlate
        };
    }

    private sealed class AnprEventBson
    {
        [BsonId]
        public ObjectId Id { get; set; }

        [BsonElement("external_event_id")]
        public string ExternalEventId { get; set; } = string.Empty;

        [BsonElement("parking_lot_id")]
        public string ParkingLotId { get; set; } = string.Empty;

        [BsonElement("camera_id")]
        public string CameraId { get; set; } = string.Empty;

        [BsonElement("plate_number")]
        public string PlateNumber { get; set; } = string.Empty;

        [BsonElement("direction")]
        public string Direction { get; set; } = string.Empty;

        [BsonElement("confidence")]
        public decimal Confidence { get; set; }

        [BsonElement("observed_at")]
        public DateTime ObservedAt { get; set; }

        public static AnprEventBson From(AnprEventDocument source) => new()
        {
            ExternalEventId = source.ExternalEventId,
            ParkingLotId = source.ParkingLotId.ToString(),
            CameraId = source.CameraId,
            PlateNumber = source.PlateNumber,
            Direction = source.Direction,
            Confidence = source.Confidence,
            ObservedAt = source.ObservedAt
        };
    }
}

/// <summary>Mongo yapılandırılmadığında kullanılan boş (no-op) telemetri deposu.</summary>
public sealed class NoOpTelemetryStore : ITelemetryStore
{
    public bool IsEnabled => false;

    public Task RecordSensorReadingAsync(
        SensorReadingDocument reading,
        CancellationToken cancellationToken) => Task.CompletedTask;

    public Task RecordAnprEventAsync(
        AnprEventDocument evt,
        CancellationToken cancellationToken) => Task.CompletedTask;

    public Task<IReadOnlyList<CoalescedSensorSpaceView>> GetCoalescedSensorSpaceViewsAsync(
        Guid parkingLotId,
        CancellationToken cancellationToken) => Task.FromResult<IReadOnlyList<CoalescedSensorSpaceView>>(
            Array.Empty<CoalescedSensorSpaceView>());

    public Task<IReadOnlyList<AnprTrendPoint>> GetAnprTrendAsync(
        Guid parkingLotId,
        DateTime fromUtc,
        DateTime toUtc,
        CancellationToken cancellationToken) => Task.FromResult<IReadOnlyList<AnprTrendPoint>>(
            Array.Empty<AnprTrendPoint>());

    public Task<ParkingLotCapacitySnapshot?> GetParkingLotCapacityAsync(
        Guid parkingLotId,
        CancellationToken cancellationToken) => Task.FromResult<ParkingLotCapacitySnapshot?>(null);

    public Task<TelemetryPurgeResult> PurgeExpiredAsync(
        DateTime utcNow,
        CancellationToken cancellationToken) => Task.FromResult(new TelemetryPurgeResult(0, 0));
}
