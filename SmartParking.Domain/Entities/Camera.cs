using SmartParking.Domain.Common;

namespace SmartParking.Domain.Entities;

public class Camera : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string RtspUrl { get; set; } = string.Empty;

    // İlişki
    public Guid ParkingLotId { get; set; }
    public ParkingLot ParkingLot { get; set; } = null!;

    public bool IsActive { get; set; }

    // Ek alanlar
    public DateTime LastMaintenanceDate { get; set; }
    public string LocationDescription { get; set; } = string.Empty;
}
