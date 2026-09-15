using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using MongoDB.Driver;
using SmartParking.Application.Interfaces;

namespace SmartParking.Infrastructure.Telemetry;

public sealed class MongoTelemetryStoreOptions
{
    public string? ConnectionString { get; set; }
    public string DatabaseName { get; set; } = "smartparking-telemetry";
    public int SensorReadingsRetentionDays { get; set; } = 365;
    public int AnprRetentionDays { get; set; } = 730;
}

public sealed class MongoTelemetryStore : ITelemetryStore
{
    private readonly IMongoDatabase _database;
    private readonly ILogger<MongoTelemetryStore> _logger;
    private readonly int _sensorRetentionDays;
    private readonly int _anprRetentionDays;

    public MongoTelemetryStore(
        IOptions<MongoTelemetryStoreOptions> options,
        ILogger<MongoTelemetryStore> logger)
    {
        _logger = logger;
        var value = options.Value;
        _sensorRetentionDays = Math.Max(7, value.SensorReadingsRetentionDays);
        _anprRetentionDays = Math.Max(7, value.AnprRetentionDays);

        var client = new MongoClient(value.ConnectionString);
        _database = client.GetDatabase(value.DatabaseName);
    }

    public bool IsEnabled => true;

    public async Task RecordSensorReadingAsync(
        SensorReadingDocument reading,
        CancellationToken cancellationToken)
    {
        try
        {
            var collection = _database.GetCollection<SensorReadingBson>("SensorReadings");
            await EnsureSensorReadingIndexesAsync(collection, cancellationToken);
            await collection.InsertOneAsync(
                SensorReadingBson.From(reading),
                cancellationToken: cancellationToken);
        }
        catch (Exception exception)
        {
            _logger.LogWarning(exception, "DocumentDB'ye sensör okuması yazılamadı (atlandı).");
        }
    }

    public async Task RecordAnprEventAsync(
        AnprEventDocument evt,
        CancellationToken cancellationToken)
    {
        try
        {
            var collection = _database.GetCollection<AnprEventBson>("AnprEvents");
            await EnsureAnprIndexesAsync(collection, cancellationToken);
            var mapped = AnprEventBson.From(evt);
            try
            {
                await collection.InsertOneAsync(mapped, cancellationToken: cancellationToken);
            }
            catch (MongoWriteException exception) when (IsDuplicateKey(exception))
            {
                _logger.LogDebug("ANPR olayı zaten mevcut: {EventId}", evt.ExternalEventId);
            }
        }
        catch (Exception exception)
        {
            _logger.LogWarning(exception, "DocumentDB'ye ANPR olayı yazılamadı (atlandı).");
        }
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
                    ExpireAfter = TimeSpan.FromDays(_sensorRetentionDays)
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
                    ExpireAfter = TimeSpan.FromDays(_anprRetentionDays)
                }),
            cancellationToken: cancellationToken);
    }

    private static bool IsDuplicateKey(MongoWriteException exception) =>
        exception.WriteError?.Category == ServerErrorCategory.DuplicateKey
        || (exception.WriteError?.Category == ServerErrorCategory.ExecutionTimeout
            && exception.WriteError.Code == 11000);

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

        [BsonElement("metadata_json")]
        public string? MetadataJson { get; set; }

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
            VehiclePlate = source.VehiclePlate,
            MetadataJson = source.MetadataJson
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

public sealed class NoOpTelemetryStore : ITelemetryStore
{
    public bool IsEnabled => false;

    public Task RecordSensorReadingAsync(
        SensorReadingDocument reading,
        CancellationToken cancellationToken) => Task.CompletedTask;

    public Task RecordAnprEventAsync(
        AnprEventDocument evt,
        CancellationToken cancellationToken) => Task.CompletedTask;
}