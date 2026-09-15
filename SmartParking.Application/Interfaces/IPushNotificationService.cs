namespace SmartParking.Application.Interfaces;

public interface IPushNotificationService
{
    bool IsEnabled { get; }

    Task<int> SendToUserAsync(
        Guid userId,
        string title,
        string body,
        IReadOnlyDictionary<string, string>? data = null,
        CancellationToken cancellationToken = default);
}
