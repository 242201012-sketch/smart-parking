using System.Globalization;
using Iyzipay;
using Iyzipay.Model;
using Iyzipay.Request;
using Microsoft.Extensions.Options;
using SmartParking.Application.Interfaces;

namespace SmartParking.Infrastructure.Payments;

public sealed class IyzicoCardPaymentService : ICardPaymentService
{
    private readonly IyzicoSettings _settings;
    private readonly Iyzipay.Options _options;

    public IyzicoCardPaymentService(IOptions<IyzicoSettings> settings)
    {
        _settings = settings.Value;
        _options = new Iyzipay.Options
        {
            ApiKey = _settings.ApiKey,
            SecretKey = _settings.SecretKey,
            BaseUrl = _settings.BaseUrl
        };
    }

    public string Provider => "iyzico";

    public bool IsEnabled =>
        _settings.Provider.Equals("iyzico", StringComparison.OrdinalIgnoreCase)
        && !string.IsNullOrWhiteSpace(_settings.ApiKey)
        && !string.IsNullOrWhiteSpace(_settings.SecretKey)
        && Uri.TryCreate(_settings.BaseUrl, UriKind.Absolute, out var apiBase)
        && IsIyzicoHttpsUri(apiBase)
        && Uri.TryCreate(_settings.CallbackBaseUrl, UriKind.Absolute, out var callback)
        && callback.Scheme == Uri.UriSchemeHttps;

    public bool IsSandbox => _settings.BaseUrl.Contains("sandbox", StringComparison.OrdinalIgnoreCase);

    public async Task<CardCheckoutSession> InitializeCheckoutAsync(
        CardCheckoutRequest input,
        CancellationToken cancellationToken = default)
    {
        if (!IsEnabled)
        {
            return new CardCheckoutSession(
                false,
                null,
                null,
                "iyzico API anahtarları veya HTTPS callback adresi yapılandırılmadı.");
        }

        var amount = input.Amount.ToString("0.00", CultureInfo.InvariantCulture);
        var contactName = $"{input.FirstName} {input.LastName}".Trim();
        var address = new Address
        {
            ContactName = contactName,
            City = input.City,
            Country = input.Country,
            Description = input.RegistrationAddress,
            ZipCode = input.ZipCode
        };
        var request = new CreateCheckoutFormInitializeRequest
        {
            Locale = Locale.TR.ToString(),
            ConversationId = input.ConversationId,
            Price = amount,
            PaidPrice = amount,
            Currency = Currency.TRY.ToString(),
            BasketId = input.BasketId,
            PaymentGroup = PaymentGroup.PRODUCT.ToString(),
            CallbackUrl = $"{_settings.CallbackBaseUrl.TrimEnd('/')}/api/payments/iyzico/callback",
            Buyer = new Buyer
            {
                Id = input.BuyerId,
                Name = input.FirstName,
                Surname = input.LastName,
                GsmNumber = input.GsmNumber,
                Email = input.Email,
                IdentityNumber = input.IdentityNumber,
                RegistrationAddress = input.RegistrationAddress,
                Ip = input.IpAddress,
                City = input.City,
                Country = input.Country,
                ZipCode = input.ZipCode
            },
            ShippingAddress = address,
            BillingAddress = address,
            BasketItems =
            [
                new BasketItem
                {
                    Id = input.BasketId,
                    Name = input.BasketItemName,
                    Category1 = "Otopark",
                    ItemType = BasketItemType.VIRTUAL.ToString(),
                    Price = amount
                }
            ]
        };

        var result = await CheckoutFormInitialize
            .Create(request, _options)
            .WaitAsync(cancellationToken);
        var succeeded = result.Status == Status.SUCCESS.ToString()
            && !string.IsNullOrWhiteSpace(result.Token)
            && Uri.TryCreate(result.PaymentPageUrl, UriKind.Absolute, out var paymentPage)
            && IsIyzicoHttpsUri(paymentPage);
        return new CardCheckoutSession(
            succeeded,
            result.Token,
            result.PaymentPageUrl,
            result.ErrorMessage);
    }

    public async Task<CardPaymentResult> RetrieveAsync(
        string conversationId,
        string token,
        CancellationToken cancellationToken = default)
    {
        var request = new RetrieveCheckoutFormRequest
        {
            ConversationId = conversationId,
            Token = token
        };
        var result = await CheckoutForm
            .Retrieve(request, _options)
            .WaitAsync(cancellationToken);
        var paidPriceText = Convert.ToString(result.PaidPrice, CultureInfo.InvariantCulture);
        decimal.TryParse(
            paidPriceText,
            NumberStyles.Number,
            CultureInfo.InvariantCulture,
            out var paidPrice);
        var fraudStatus = Convert.ToInt32(result.FraudStatus, CultureInfo.InvariantCulture);
        return new CardPaymentResult(
            result.Status == Status.SUCCESS.ToString(),
            result.ConversationId ?? string.Empty,
            result.Token ?? string.Empty,
            result.PaymentId ?? string.Empty,
            result.PaymentStatus ?? string.Empty,
            paidPrice,
            fraudStatus,
            result.ErrorMessage);
    }

    private static bool IsIyzicoHttpsUri(Uri uri) =>
        uri.Scheme == Uri.UriSchemeHttps
        && (uri.Host.Equals("iyzipay.com", StringComparison.OrdinalIgnoreCase)
            || uri.Host.EndsWith(".iyzipay.com", StringComparison.OrdinalIgnoreCase));
}
