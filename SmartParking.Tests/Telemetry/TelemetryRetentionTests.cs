using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using SmartParking.API.BackgroundServices;
using SmartParking.Application.Interfaces;
using SmartParking.Infrastructure.Telemetry;
using Xunit;

public class TelemetryRetentionTests
{
    [Fact]
    public async Task NoOpStore_PurgeExpiredAsync_ReturnsZeros()
    {
        var store = new NoOpTelemetryStore();

        Assert.False(store.IsEnabled);
        var result = await store.PurgeExpiredAsync(DateTime.UtcNow, CancellationToken.None);

        Assert.Equal(0, result.DeletedSensorReadings);
        Assert.Equal(0, result.DeletedAnprEvents);
    }

    [Fact]
    public async Task RetentionService_PurgesOnce_WhenStoreEnabled()
    {
        var store = new StubTelemetryStore { IsEnabled = true };
        var options = Options.Create(new MongoTelemetryStoreOptions
        {
            RetentionIntervalHours = 24
        });
        var service = new TelemetryRetentionService(
            store, options, NullLogger<TelemetryRetentionService>.Instance);

        await service.StartAsync(CancellationToken.None);
        await Task.Delay(TimeSpan.FromSeconds(2));
        await service.StopAsync(CancellationToken.None);

        Assert.True(store.PurgeCalls >= 1);
    }

    [Fact]
    public async Task RetentionService_SkipsPurge_WhenStoreDisabled()
    {
        var store = new StubTelemetryStore { IsEnabled = false };
        var options = Options.Create(new MongoTelemetryStoreOptions
        {
            RetentionIntervalHours = 24
        });
        var service = new TelemetryRetentionService(
            store, options, NullLogger<TelemetryRetentionService>.Instance);

        await service.StartAsync(CancellationToken.None);
        await Task.Delay(TimeSpan.FromSeconds(2));
        await service.StopAsync(CancellationToken.None);

        Assert.Equal(0, store.PurgeCalls);
    }

    private sealed class StubTelemetryStore : ITelemetryStore
    {
        public bool IsEnabled { get; set; }
        public int PurgeCalls { get; private set; }

        public Task RecordSensorReadingAsync(
            SensorReadingDocument reading, CancellationToken cancellationToken) =>
            Task.CompletedTask;

        public Task RecordAnprEventAsync(
            AnprEventDocument evt, CancellationToken cancellationToken) =>
            Task.CompletedTask;

        public Task<IReadOnlyList<CoalescedSensorSpaceView>> GetCoalescedSensorSpaceViewsAsync(
            Guid parkingLotId, CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<CoalescedSensorSpaceView>>(
                Array.Empty<CoalescedSensorSpaceView>());

        public Task<IReadOnlyList<AnprTrendPoint>> GetAnprTrendAsync(
            Guid parkingLotId, DateTime fromUtc, DateTime toUtc, CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<AnprTrendPoint>>(Array.Empty<AnprTrendPoint>());

        public Task<ParkingLotCapacitySnapshot?> GetParkingLotCapacityAsync(
            Guid parkingLotId, CancellationToken cancellationToken) =>
            Task.FromResult<ParkingLotCapacitySnapshot?>(null);

        public Task<TelemetryPurgeResult> PurgeExpiredAsync(
            DateTime utcNow, CancellationToken cancellationToken)
        {
            PurgeCalls++;
            return Task.FromResult(new TelemetryPurgeResult(5, 3));
        }
    }
}
