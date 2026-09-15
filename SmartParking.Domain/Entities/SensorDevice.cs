using SmartParking.Domain.Common;

namespace SmartParking.Domain.Entities;

public class SensorDevice : BaseEntity
{
    public string DeviceId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public Guid ParkingLotId { get; set; }
    public ParkingLot ParkingLot { get; set; } = null!;
    public string? FirmwareVersion { get; set; }
    public int? BatteryPercent { get; set; }
    public DateTime? LastSeenAt { get; set; }
    public bool IsActive { get; set; } = true;
}
