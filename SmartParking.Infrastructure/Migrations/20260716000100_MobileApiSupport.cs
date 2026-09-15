using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using SmartParking.Infrastructure.Persistence;

#nullable disable

namespace SmartParking.Infrastructure.Migrations;

[DbContext(typeof(ApplicationDbContext))]
[Migration("20260716000100_MobileApiSupport")]
public sealed class MobileApiSupport : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<DateTime>(
            name: "CreatedAt", table: "ParkingLots", type: "datetime2",
            nullable: false, defaultValueSql: "SYSUTCDATETIME()");
        migrationBuilder.AddColumn<bool>(
            name: "IsActive", table: "ParkingLots", type: "bit",
            nullable: false, defaultValue: true);
        migrationBuilder.AddColumn<DateTime>(
            name: "LastOccupiedAt", table: "ParkingSpaces", type: "datetime2",
            nullable: true);
        migrationBuilder.AddColumn<string>(
            name: "VehiclePlate", table: "ParkingSpaces", type: "nvarchar(max)",
            nullable: true);
        migrationBuilder.AddColumn<DateTime>(
            name: "LastMaintenanceDate", table: "Cameras", type: "datetime2",
            nullable: false, defaultValue: new DateTime(2000, 1, 1));
        migrationBuilder.AddColumn<string>(
            name: "LocationDescription", table: "Cameras", type: "nvarchar(max)",
            nullable: false, defaultValue: string.Empty);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropColumn(name: "CreatedAt", table: "ParkingLots");
        migrationBuilder.DropColumn(name: "IsActive", table: "ParkingLots");
        migrationBuilder.DropColumn(name: "LastOccupiedAt", table: "ParkingSpaces");
        migrationBuilder.DropColumn(name: "VehiclePlate", table: "ParkingSpaces");
        migrationBuilder.DropColumn(name: "LastMaintenanceDate", table: "Cameras");
        migrationBuilder.DropColumn(name: "LocationDescription", table: "Cameras");
    }
}
