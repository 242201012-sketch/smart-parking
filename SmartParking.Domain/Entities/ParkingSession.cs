using SmartParking.Domain.Common;

namespace SmartParking.Domain.Entities;

public class ParkingSession : BaseEntity
{
    public Guid UserId { get; set; }
    public Guid ParkingLotId { get; set; }
    public ParkingLot ParkingLot { get; set; } = null!;
    public Guid? ParkingSpaceId { get; set; }
    public ParkingSpace? ParkingSpace { get; set; }
    public string VehiclePlate { get; set; } = string.Empty;
    public DateTime StartedAt { get; set; }
    public DateTime? EndedAt { get; set; }
    public decimal? TotalAmount { get; set; }
    public string PaymentStatus { get; set; } = "pending";
}
