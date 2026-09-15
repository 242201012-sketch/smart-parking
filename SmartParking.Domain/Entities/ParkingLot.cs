namespace SmartParking.Domain.Entities;

public class ParkingLot
{
    public Guid Id { get; set; }
    public string ExternalCode { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Address { get; set; } = string.Empty;
    public string Zone { get; set; } = string.Empty;

    public double Latitude { get; set; }
    public double Longitude { get; set; }

    public int TotalCapacity { get; set; }
    public int AvailableCapacity { get; set; }
    public decimal HourlyRate { get; set; }
    public bool HasElectricCharging { get; set; }
    public bool HasAccessibleSpaces { get; set; }
    public bool IsCovered { get; set; }

    // İlişkiler
    public ICollection<ParkingSpace> Spaces { get; set; } = new List<ParkingSpace>();
    public ICollection<Camera> Cameras { get; set; } = new List<Camera>();
    public ICollection<SensorDevice> SensorDevices { get; set; } = new List<SensorDevice>();

    // Ek alanlar
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }
}
