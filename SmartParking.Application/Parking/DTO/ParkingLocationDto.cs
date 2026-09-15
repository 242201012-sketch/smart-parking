namespace SmartParking.Application.Parking.DTO;

public sealed record ParkingLocationDto(
    Guid Id,
    string Name,
    string Address,
    double Latitude,
    double Longitude,
    int TotalCapacity,
    int AvailableCapacity,
    double? DistanceKm,
    string Zone,
    decimal HourlyRate,
    bool HasElectricCharging,
    bool HasAccessibleSpaces,
    bool IsCovered,
    DateTime? UpdatedAt);
