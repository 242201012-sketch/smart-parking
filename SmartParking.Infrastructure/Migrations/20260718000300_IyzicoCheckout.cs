using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using SmartParking.Infrastructure.Persistence;

#nullable disable

namespace SmartParking.Infrastructure.Migrations;

[DbContext(typeof(ApplicationDbContext))]
[Migration("20260718000300_IyzicoCheckout")]
public sealed class IyzicoCheckout : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<string>(
            name: "FailureReason",
            table: "PaymentRecords",
            maxLength: 500,
            nullable: true);
        migrationBuilder.AddColumn<DateTime>(
            name: "PaidAt",
            table: "PaymentRecords",
            nullable: true);
        migrationBuilder.AddColumn<string>(
            name: "ProviderConversationId",
            table: "PaymentRecords",
            maxLength: 128,
            nullable: true);
        migrationBuilder.AddColumn<string>(
            name: "ProviderToken",
            table: "PaymentRecords",
            maxLength: 256,
            nullable: true);
        migrationBuilder.CreateIndex(
            name: "IX_PaymentRecords_ProviderToken",
            table: "PaymentRecords",
            column: "ProviderToken");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropIndex(
            name: "IX_PaymentRecords_ProviderToken",
            table: "PaymentRecords");
        migrationBuilder.DropColumn(name: "FailureReason", table: "PaymentRecords");
        migrationBuilder.DropColumn(name: "PaidAt", table: "PaymentRecords");
        migrationBuilder.DropColumn(name: "ProviderConversationId", table: "PaymentRecords");
        migrationBuilder.DropColumn(name: "ProviderToken", table: "PaymentRecords");
    }
}
