using SmartParking.Domain.Common;

namespace SmartParking.Domain.Entities;

public class Vehicle : BaseEntity
{
    public Guid UserId { get; set; }
    public string PlateNumber { get; set; } = string.Empty;
    public string Brand { get; set; } = string.Empty;
    public string Model { get; set; } = string.Empty;
    public string Color { get; set; } = string.Empty;

    // İlişkiler
    public ICollection<Reservation> Reservations { get; set; } = new List<Reservation>();
}
