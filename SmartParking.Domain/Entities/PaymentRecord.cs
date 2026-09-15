using SmartParking.Domain.Common;

namespace SmartParking.Domain.Entities;

public class PaymentRecord : BaseEntity
{
    public Guid UserId { get; set; }
    public Guid ParkingSessionId { get; set; }
    public ParkingSession ParkingSession { get; set; } = null!;
    public string Provider { get; set; } = string.Empty;
    public string? ProviderReference { get; set; }
    public string? ProviderToken { get; set; }
    public string? ProviderConversationId { get; set; }
    public decimal Amount { get; set; }
    public string Currency { get; set; } = "TRY";
    public string Status { get; set; } = "pending";
    public string? FailureReason { get; set; }
    public DateTime? PaidAt { get; set; }
}
