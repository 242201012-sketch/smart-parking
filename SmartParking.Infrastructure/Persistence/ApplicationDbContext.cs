using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

using SmartParking.Domain.Entities;
using SmartParking.Infrastructure.Identity;

namespace SmartParking.Infrastructure.Persistence;

public class ApplicationDbContext
    : IdentityDbContext<AppUser, IdentityRole<Guid>, Guid>
{
    public ApplicationDbContext(
        DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    public DbSet<ParkingLot> ParkingLots => Set<ParkingLot>();
    public DbSet<ParkingSpace> ParkingSpaces => Set<ParkingSpace>();
    public DbSet<Reservation> Reservations => Set<Reservation>();
    public DbSet<Vehicle> Vehicles => Set<Vehicle>();
    public DbSet<Camera> Cameras => Set<Camera>();
    public DbSet<SensorDevice> SensorDevices => Set<SensorDevice>();
    public DbSet<SensorReading> SensorReadings => Set<SensorReading>();
    public DbSet<Favorite> Favorites => Set<Favorite>();
    public DbSet<UserNotification> UserNotifications => Set<UserNotification>();
    public DbSet<ParkingSession> ParkingSessions => Set<ParkingSession>();
    public DbSet<PaymentRecord> PaymentRecords => Set<PaymentRecord>();
    public DbSet<AnprEvent> AnprEvents => Set<AnprEvent>();
    public DbSet<PushDevice> PushDevices => Set<PushDevice>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        builder.Entity<ParkingLot>(entity =>
        {
            entity.HasIndex(item => item.ExternalCode).IsUnique();
            entity.Property(item => item.HourlyRate).HasPrecision(10, 2);
        });

        builder.Entity<ParkingSpace>(entity =>
        {
            entity.HasIndex(item => new { item.ParkingLotId, item.Code }).IsUnique();
            entity.HasOne(item => item.ParkingLot)
                .WithMany(item => item.Spaces)
                .HasForeignKey(item => item.ParkingLotId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<Vehicle>(entity =>
            entity.HasIndex(item => new { item.UserId, item.PlateNumber }).IsUnique());

        builder.Entity<Reservation>(entity =>
        {
            entity.HasIndex(item => item.QrToken).IsUnique();
            entity.Property(item => item.EstimatedAmount).HasPrecision(10, 2);
            entity.Ignore(item => item.Status);
            entity.HasOne(item => item.ParkingSpace)
                .WithMany()
                .HasForeignKey(item => item.ParkingSpaceId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<SensorDevice>(entity =>
        {
            entity.HasIndex(item => item.DeviceId).IsUnique();
            entity.HasOne(item => item.ParkingLot)
                .WithMany(item => item.SensorDevices)
                .HasForeignKey(item => item.ParkingLotId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<SensorReading>(entity =>
        {
            entity.HasIndex(item => new { item.DeviceId, item.Sequence }).IsUnique();
            entity.HasIndex(item => item.ObservedAt);
            entity.HasOne(item => item.ParkingSpace)
                .WithMany()
                .HasForeignKey(item => item.ParkingSpaceId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<Favorite>(entity =>
        {
            entity.HasIndex(item => new { item.UserId, item.ParkingLotId }).IsUnique();
            entity.HasOne(item => item.ParkingLot)
                .WithMany()
                .HasForeignKey(item => item.ParkingLotId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<UserNotification>(entity =>
            entity.HasIndex(item => new { item.UserId, item.IsRead }));

        builder.Entity<ParkingSession>(entity =>
        {
            entity.Property(item => item.TotalAmount).HasPrecision(10, 2);
            entity.HasOne(item => item.ParkingLot)
                .WithMany()
                .HasForeignKey(item => item.ParkingLotId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(item => item.ParkingSpace)
                .WithMany()
                .HasForeignKey(item => item.ParkingSpaceId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        builder.Entity<PaymentRecord>(entity =>
        {
            entity.Property(item => item.Amount).HasPrecision(10, 2);
            entity.Property(item => item.Provider).HasMaxLength(32);
            entity.Property(item => item.ProviderReference).HasMaxLength(128);
            entity.Property(item => item.ProviderToken).HasMaxLength(256);
            entity.Property(item => item.ProviderConversationId).HasMaxLength(128);
            entity.Property(item => item.Currency).HasMaxLength(3);
            entity.Property(item => item.Status).HasMaxLength(32);
            entity.Property(item => item.FailureReason).HasMaxLength(500);
            entity.HasIndex(item => item.ProviderToken);
            entity.HasOne(item => item.ParkingSession)
                .WithMany()
                .HasForeignKey(item => item.ParkingSessionId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<AnprEvent>(entity =>
        {
            entity.HasIndex(item => item.ExternalEventId).IsUnique();
            entity.Property(item => item.Confidence).HasPrecision(5, 4);
            entity.HasOne(item => item.ParkingLot)
                .WithMany()
                .HasForeignKey(item => item.ParkingLotId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<PushDevice>(entity =>
        {
            entity.HasIndex(item => item.TokenHash).IsUnique();
            entity.HasIndex(item => new { item.UserId, item.IsActive });
            entity.Property(item => item.Token).HasMaxLength(4096);
            entity.Property(item => item.TokenHash).HasMaxLength(64);
            entity.Property(item => item.Platform).HasMaxLength(32);
            entity.Property(item => item.DeviceName).HasMaxLength(160);
        });
    }
}
