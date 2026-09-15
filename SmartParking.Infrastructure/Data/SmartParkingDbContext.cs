using Microsoft.EntityFrameworkCore;
using SmartParking.Domain.Entities;

namespace SmartParking.Infrastructure.Data
{
    public class SmartParkingDbContext : DbContext
    {
        public SmartParkingDbContext(DbContextOptions<SmartParkingDbContext> options)
            : base(options)
        {
        }

        public DbSet<ParkingSpot> ParkingSpots { get; set; } = null!;
        public DbSet<ParkingHistory> ParkingHistories { get; set; } = null!;
    }
}
