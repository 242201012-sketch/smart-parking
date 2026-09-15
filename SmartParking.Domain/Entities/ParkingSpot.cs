namespace SmartParking.Domain.Entities;

public class ParkingSpot
{
    public int Id { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public bool IsAvailable { get; set; }
    public ICollection<ParkingHistory> History { get; set; } = new List<ParkingHistory>();
}

public class ParkingHistory
{
    public int Id { get; set; }
    public int ParkingSpotId { get; set; }
    public DateTime Timestamp { get; set; }
    public bool IsAvailable { get; set; }

    public ParkingSpot ParkingSpot { get; set; } = null!;
}
