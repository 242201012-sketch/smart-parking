namespace SmartParking.Application.Interfaces;

public interface ICardPaymentService
{
    string Provider { get; }
    bool IsEnabled { get; }
    bool IsSandbox { get; }

    Task<CardCheckoutSession> InitializeCheckoutAsync(
        CardCheckoutRequest request,
        CancellationToken cancellationToken = default);

    Task<CardPaymentResult> RetrieveAsync(
        string conversationId,
        string token,
        CancellationToken cancellationToken = default);
}

public sealed record CardCheckoutRequest(
    string ConversationId,
    decimal Amount,
    string BuyerId,
    string FirstName,
    string LastName,
    string Email,
    string GsmNumber,
    string IdentityNumber,
    string RegistrationAddress,
    string City,
    string Country,
    string ZipCode,
    string IpAddress,
    string BasketId,
    string BasketItemName);

public sealed record CardCheckoutSession(
    bool Success,
    string? Token,
    string? PaymentPageUrl,
    string? ErrorMessage);

public sealed record CardPaymentResult(
    bool RequestSucceeded,
    string ConversationId,
    string Token,
    string PaymentId,
    string PaymentStatus,
    decimal PaidPrice,
    int FraudStatus,
    string? ErrorMessage);
