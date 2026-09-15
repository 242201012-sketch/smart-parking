using SmartParking.Domain.Common;

namespace SmartParking.Domain.Entities;

public class Reservation : BaseEntity
{
    public Guid UserId { get; set; }
    public Guid VehicleId { get; set; }
    public Vehicle Vehicle { get; set; } = null!;

    public Guid ParkingSpaceId { get; set; }
    public ParkingSpace ParkingSpace { get; set; } = null!;

    public DateTime StartTime { get; set; }
    public DateTime EndTime { get; set; }

    public bool IsActive { get; set; }
    public bool IsCancelled { get; set; }
    public string QrToken { get; set; } = string.Empty;
    public decimal EstimatedAmount { get; set; }

    // Ek alanlar
    public string Status => IsCancelled ? "İptal" : IsActive ? "Aktif" : "Tamamlandı";
}
