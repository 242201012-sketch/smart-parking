using SmartParking.Domain.Common;

namespace SmartParking.Domain.Entities;

public class SensorReading : BaseEntity
{
    public string DeviceId { get; set; } = string.Empty;
    public long Sequence { get; set; }
    public Guid ParkingLotId { get; set; }
    public Guid ParkingSpaceId { get; set; }
    public ParkingSpace ParkingSpace { get; set; } = null!;
    public bool IsOccupied { get; set; }
    public DateTime ObservedAt { get; set; }
    public int? BatteryPercent { get; set; }
    public string? VehiclePlate { get; set; }
    public string? MetadataJson { get; set; }
}
