using Microsoft.EntityFrameworkCore;
using SmartParking.Application.Interfaces;
using SmartParking.Application.Parking.DTO;
using SmartParking.Domain.Entities;
using SmartParking.Infrastructure.Persistence;

namespace SmartParking.Infrastructure.Services
{
    public class ParkingService : IParkingService
    {
        private readonly ApplicationDbContext _context;

        public ParkingService(ApplicationDbContext context)
        {
            _context = context ?? throw new ArgumentNullException(nameof(context));
        }

        public async Task<IReadOnlyList<ParkingLocationDto>> GetAllAsync()
        {
            var parkingLots = await _context.ParkingLots
                .AsNoTracking()
                .Include(p => p.Spaces)
                .Where(p => p.IsActive)
                .OrderBy(p => p.Name)
                .ToListAsync();

            return parkingLots.Select(p => ToDto(p, null)).ToList();
        }

        public async Task<ParkingLocationDto?> GetByIdAsync(Guid id)
        {
            var parkingLot = await _context.ParkingLots
                .AsNoTracking()
                .Include(p => p.Spaces)
                .FirstOrDefaultAsync(p => p.Id == id && p.IsActive);

            return parkingLot is null ? null : ToDto(parkingLot, null);
        }

        public async Task<ParkingLocationDto?> GetNearestAvailableAsync(
            double latitude,
            double longitude)
        {
            var now = DateTime.UtcNow;
            var parkingLots = await _context.ParkingLots
                .AsNoTracking()
                .Include(p => p.Spaces)
                .Where(p => p.IsActive && p.Spaces.Any(s =>
                    !s.IsOccupied && (!s.IsReserved || s.ReservedUntil <= now)))
                .ToListAsync();

            return parkingLots
                .Select(p => ToDto(p, DistanceInKm(
                    latitude,
                    longitude,
                    p.Latitude,
                    p.Longitude)))
                .OrderBy(p => p.DistanceKm)
                .FirstOrDefault();
        }

        private static ParkingLocationDto ToDto(ParkingLot parkingLot, double? distanceKm)
        {
            var now = DateTime.UtcNow;
            var available = parkingLot.Spaces.Count(space =>
                !space.IsOccupied && (!space.IsReserved || space.ReservedUntil <= now));
            var total = parkingLot.TotalCapacity > 0
                ? parkingLot.TotalCapacity
                : parkingLot.Spaces.Count;

            return new ParkingLocationDto(
                parkingLot.Id,
                parkingLot.Name,
                parkingLot.Address,
                parkingLot.Latitude,
                parkingLot.Longitude,
                total,
                available,
                distanceKm is null ? null : Math.Round(distanceKm.Value, 2),
                parkingLot.Zone,
                parkingLot.HourlyRate,
                parkingLot.HasElectricCharging,
                parkingLot.HasAccessibleSpaces,
                parkingLot.IsCovered,
                parkingLot.UpdatedAt);
        }

        private static double DistanceInKm(
            double latitude1,
            double longitude1,
            double latitude2,
            double longitude2)
        {
            const double earthRadiusKm = 6371;
            var latitudeDelta = DegreesToRadians(latitude2 - latitude1);
            var longitudeDelta = DegreesToRadians(longitude2 - longitude1);
            var firstLatitude = DegreesToRadians(latitude1);
            var secondLatitude = DegreesToRadians(latitude2);

            var a = Math.Sin(latitudeDelta / 2) * Math.Sin(latitudeDelta / 2) +
                    Math.Cos(firstLatitude) * Math.Cos(secondLatitude) *
                    Math.Sin(longitudeDelta / 2) * Math.Sin(longitudeDelta / 2);

            return earthRadiusKm * 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        }

        private static double DegreesToRadians(double degrees) => degrees * Math.PI / 180;
    }
}
