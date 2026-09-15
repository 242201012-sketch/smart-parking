namespace SmartParking.Domain.Entities;

public class ParkingSpace
{
    public Guid Id { get; set; }
    public Guid ParkingLotId { get; set; }

    public string Code { get; set; } = string.Empty;
    public bool IsOccupied { get; set; }
    public bool IsReserved { get; set; }
    public DateTime? ReservedUntil { get; set; }
    public bool IsElectric { get; set; }
    public bool IsAccessible { get; set; }

    public ParkingLot ParkingLot { get; set; } = null!;

    // Ek alanlar
    public string? VehiclePlate { get; set; }
    public DateTime? LastOccupiedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}
