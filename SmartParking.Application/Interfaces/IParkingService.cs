using SmartParking.Application.Parking.DTO;

namespace SmartParking.Application.Interfaces
{
    public interface IParkingService
    {
        Task<IReadOnlyList<ParkingLocationDto>> GetAllAsync();
        Task<ParkingLocationDto?> GetByIdAsync(Guid id);
        Task<ParkingLocationDto?> GetNearestAvailableAsync(double latitude, double longitude);
    }
}
