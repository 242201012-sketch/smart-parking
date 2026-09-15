using SmartParking.Domain.Common;

namespace SmartParking.Domain.Entities;

public class AnprEvent : BaseEntity
{
    public string ExternalEventId { get; set; } = string.Empty;
    public Guid ParkingLotId { get; set; }
    public ParkingLot ParkingLot { get; set; } = null!;
    public string CameraId { get; set; } = string.Empty;
    public string PlateNumber { get; set; } = string.Empty;
    public string Direction { get; set; } = string.Empty;
    public decimal Confidence { get; set; }
    public DateTime ObservedAt { get; set; }
}
