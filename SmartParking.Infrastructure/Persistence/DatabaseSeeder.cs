using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Configuration;
using SmartParking.Domain.Entities;
using SmartParking.Infrastructure.Identity;

namespace SmartParking.Infrastructure.Persistence;

public static class DatabaseSeeder
{
    public static async Task SeedAsync(IServiceProvider services)
    {
        await using var scope = services.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var configuration = scope.ServiceProvider.GetRequiredService<Microsoft.Extensions.Configuration.IConfiguration>();

        var useEnsureCreated = configuration.GetValue("Database:UseEnsureCreated", false);
        if (useEnsureCreated)
        {
            await context.Database.EnsureCreatedAsync();
            await EnsureCompatibilitySchemaAsync(context);
        }
        else
            await context.Database.MigrateAsync();

        var roleManager = scope.ServiceProvider.GetRequiredService<RoleManager<IdentityRole<Guid>>>();
        foreach (var roleName in new[] { "User", "Admin" })
        {
            if (!await roleManager.RoleExistsAsync(roleName))
                await roleManager.CreateAsync(new IdentityRole<Guid>(roleName));
        }

        await SeedNationalParkingLotsAsync(context);

        await SeedAdminAsync(scope.ServiceProvider, configuration);
    }

    private static async Task SeedNationalParkingLotsAsync(ApplicationDbContext context)
    {
        var existingLots = await context.ParkingLots
            .Include(item => item.Spaces)
            .ToListAsync();
        var lotsByCode = existingLots.ToDictionary(
            item => item.ExternalCode,
            StringComparer.OrdinalIgnoreCase);

        // Eski Amasya pilot kayıtlarını yeni il filtresiyle uyumlu tutarız.
        foreach (var lot in existingLots.Where(item =>
                     item.Address.Contains("Amasya", StringComparison.OrdinalIgnoreCase)))
        {
            lot.Zone = "Amasya";
        }

        foreach (var seed in NationalParkingSeedData.All)
        {
            var externalCode = seed.PlateCode == 5
                ? "AMASYA-MERKEZ"
                : $"TR-{seed.PlateCode:00}";
            if (lotsByCode.TryGetValue(externalCode, out var existing))
            {
                existing.Zone = seed.Province;
                existing.UpdatedAt = DateTime.UtcNow;
                continue;
            }

            var capacity = 48 + seed.PlateCode % 5 * 12;
            var occupiedCount = 10 + seed.PlateCode * 7 % (capacity - 16);
            var hourlyRate = 30 + seed.PlateCode % 6 * 5;
            var parkingLot = CreateParkingLot(
                externalCode,
                $"{seed.Province} Merkez Akıllı Otoparkı",
                $"{seed.Province} Merkez / Türkiye",
                seed.Province,
                seed.Latitude,
                seed.Longitude,
                capacity,
                occupiedCount,
                hourlyRate,
                seed.PlateCode % 3 == 0,
                true,
                seed.PlateCode % 2 == 0);
            context.ParkingLots.Add(parkingLot);
            lotsByCode[externalCode] = parkingLot;
        }

        await context.SaveChangesAsync();
    }

    private static async Task EnsureCompatibilitySchemaAsync(ApplicationDbContext context)
    {
        if (!context.Database.IsNpgsql()) return;

        // EnsureCreated mevcut bir veritabanına yeni tablolar eklemez. Render/Cloud SQL
        // üzerinde eski bir kurulum varsa FCM cihaz tablosunu güvenle tamamlarız.
        await context.Database.ExecuteSqlRawAsync(@"
            CREATE TABLE IF NOT EXISTS ""PushDevices"" (
                ""Id"" uuid NOT NULL,
                ""UserId"" uuid NOT NULL,
                ""Token"" character varying(4096) NOT NULL,
                ""TokenHash"" character varying(64) NOT NULL,
                ""Platform"" character varying(32) NOT NULL,
                ""DeviceName"" character varying(160) NOT NULL,
                ""IsActive"" boolean NOT NULL,
                ""LastSeenAt"" timestamp with time zone NOT NULL,
                ""CreatedAt"" timestamp with time zone NOT NULL,
                ""UpdatedAt"" timestamp with time zone NULL,
                ""IsDeleted"" boolean NOT NULL,
                CONSTRAINT ""PK_PushDevices"" PRIMARY KEY (""Id"")
            );");
        await context.Database.ExecuteSqlRawAsync(@"
            CREATE UNIQUE INDEX IF NOT EXISTS ""IX_PushDevices_TokenHash""
            ON ""PushDevices"" (""TokenHash"");");
        await context.Database.ExecuteSqlRawAsync(@"
            CREATE INDEX IF NOT EXISTS ""IX_PushDevices_UserId_IsActive""
            ON ""PushDevices"" (""UserId"", ""IsActive"");");
        await context.Database.ExecuteSqlRawAsync(@"
            ALTER TABLE ""PaymentRecords""
            ADD COLUMN IF NOT EXISTS ""ProviderToken"" character varying(256) NULL;
            ALTER TABLE ""PaymentRecords""
            ADD COLUMN IF NOT EXISTS ""ProviderConversationId"" character varying(128) NULL;
            ALTER TABLE ""PaymentRecords""
            ADD COLUMN IF NOT EXISTS ""FailureReason"" character varying(500) NULL;
            ALTER TABLE ""PaymentRecords""
            ADD COLUMN IF NOT EXISTS ""PaidAt"" timestamp with time zone NULL;");
        await context.Database.ExecuteSqlRawAsync(@"
            CREATE INDEX IF NOT EXISTS ""IX_PaymentRecords_ProviderToken""
            ON ""PaymentRecords"" (""ProviderToken"");");
    }

    private static ParkingLot CreateParkingLot(
        string externalCode,
        string name,
        string address,
        string zone,
        double latitude,
        double longitude,
        int capacity,
        int occupiedCount,
        decimal hourlyRate,
        bool hasElectricCharging,
        bool hasAccessibleSpaces,
        bool isCovered)
    {
        var lot = new ParkingLot
        {
            Id = Guid.NewGuid(),
            ExternalCode = externalCode,
            Name = name,
            Address = address,
            Zone = zone,
            Latitude = latitude,
            Longitude = longitude,
            TotalCapacity = capacity,
            AvailableCapacity = capacity - occupiedCount,
            HourlyRate = hourlyRate,
            HasElectricCharging = hasElectricCharging,
            HasAccessibleSpaces = hasAccessibleSpaces,
            IsCovered = isCovered,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        for (var index = 1; index <= capacity; index++)
        {
            lot.Spaces.Add(new ParkingSpace
            {
                Id = Guid.NewGuid(),
                ParkingLotId = lot.Id,
                Code = $"P{index:00}",
                IsOccupied = index <= occupiedCount,
                IsElectric = hasElectricCharging && index > occupiedCount && index % 10 == 0,
                IsAccessible = hasAccessibleSpaces && index > occupiedCount && index % 12 == 0,
                ParkingLot = lot
            });
        }

        return lot;
    }

    private static async Task SeedAdminAsync(
        IServiceProvider services,
        Microsoft.Extensions.Configuration.IConfiguration configuration)
    {
        var email = configuration["Admin:Email"];
        var password = configuration["Admin:Password"];
        if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password))
            return;

        var userManager = services.GetRequiredService<UserManager<AppUser>>();
        var admin = await userManager.FindByEmailAsync(email);
        if (admin is null)
        {
            admin = new AppUser
            {
                UserName = email,
                Email = email,
                FullName = "SmartParking Yöneticisi",
                EmailConfirmed = true
            };
            var result = await userManager.CreateAsync(admin, password);
            if (!result.Succeeded)
                throw new InvalidOperationException(
                    $"Yönetici hesabı oluşturulamadı: {string.Join(" | ", result.Errors.Select(error => error.Description))}");
        }

        if (!await userManager.IsInRoleAsync(admin, "Admin"))
            await userManager.AddToRoleAsync(admin, "Admin");
        if (!await userManager.IsInRoleAsync(admin, "User"))
            await userManager.AddToRoleAsync(admin, "User");
    }
}
