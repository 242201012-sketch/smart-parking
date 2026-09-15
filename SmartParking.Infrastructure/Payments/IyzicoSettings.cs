namespace SmartParking.Infrastructure.Payments;

public sealed class IyzicoSettings
{
    public string Provider { get; set; } = "disabled";
    public string ApiKey { get; set; } = string.Empty;
    public string SecretKey { get; set; } = string.Empty;
    public string BaseUrl { get; set; } = "https://sandbox-api.iyzipay.com";
    public string CallbackBaseUrl { get; set; } = string.Empty;
    public string ReturnScheme { get; set; } = "smartparking://payment-result";
}
