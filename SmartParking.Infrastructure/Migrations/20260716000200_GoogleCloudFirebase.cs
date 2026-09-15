using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using SmartParking.Infrastructure.Persistence;

#nullable disable

namespace SmartParking.Infrastructure.Migrations;

[DbContext(typeof(ApplicationDbContext))]
[Migration("20260716000200_GoogleCloudFirebase")]
public sealed class GoogleCloudFirebase : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "PushDevices",
            columns: table => new
            {
                Id = table.Column<Guid>(nullable: false),
                UserId = table.Column<Guid>(nullable: false),
                Token = table.Column<string>(maxLength: 4096, nullable: false),
                TokenHash = table.Column<string>(maxLength: 64, nullable: false),
                Platform = table.Column<string>(maxLength: 32, nullable: false),
                DeviceName = table.Column<string>(maxLength: 160, nullable: false),
                IsActive = table.Column<bool>(nullable: false),
                LastSeenAt = table.Column<DateTime>(nullable: false),
                CreatedAt = table.Column<DateTime>(nullable: false),
                UpdatedAt = table.Column<DateTime>(nullable: true),
                IsDeleted = table.Column<bool>(nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_PushDevices", item => item.Id);
            });

        migrationBuilder.CreateIndex(
            name: "IX_PushDevices_TokenHash",
            table: "PushDevices",
            column: "TokenHash",
            unique: true);

        migrationBuilder.CreateIndex(
            name: "IX_PushDevices_UserId_IsActive",
            table: "PushDevices",
            columns: new[] { "UserId", "IsActive" });
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "PushDevices");
    }
}
