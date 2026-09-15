using FirebaseAdmin.Messaging;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using SmartParking.Application.Interfaces;
using SmartParking.Infrastructure.Persistence;

namespace SmartParking.Infrastructure.Firebase;

public sealed class FirebasePushNotificationService : IPushNotificationService
{
    private readonly ApplicationDbContext _context;
    private readonly FirebaseAdminProvider _provider;
    private readonly ILogger<FirebasePushNotificationService> _logger;

    public FirebasePushNotificationService(
        ApplicationDbContext context,
        FirebaseAdminProvider provider,
        ILogger<FirebasePushNotificationService> logger)
    {
        _context = context;
        _provider = provider;
        _logger = logger;
    }

    public bool IsEnabled => _provider.IsEnabled && _provider.Messaging is not null;

    public async Task<int> SendToUserAsync(
        Guid userId,
        string title,
        string body,
        IReadOnlyDictionary<string, string>? data = null,
        CancellationToken cancellationToken = default)
    {
        if (!IsEnabled) return 0;

        var devices = await _context.PushDevices
            .Where(device => device.UserId == userId && device.IsActive && !device.IsDeleted)
            .OrderByDescending(device => device.LastSeenAt)
            .Take(500)
            .ToListAsync(cancellationToken);
        if (devices.Count == 0) return 0;

        var messageData = data is null
            ? new Dictionary<string, string>()
            : new Dictionary<string, string>(data);
        messageData["title"] = title;
        messageData["body"] = body;

        try
        {
            var response = await _provider.Messaging!.SendEachForMulticastAsync(
                new MulticastMessage
                {
                    Tokens = devices.Select(device => device.Token).ToList(),
                    Notification = new Notification { Title = title, Body = body },
                    Data = messageData,
                    Android = new AndroidConfig
                    {
                        Priority = Priority.High,
                        Notification = new AndroidNotification
                        {
                            ChannelId = "smartparking_updates",
                            Icon = "ic_launcher",
                            Sound = "default",
                            ClickAction = "FLUTTER_NOTIFICATION_CLICK"
                        }
                    }
                },
                cancellationToken);

            var changed = false;
            for (var index = 0; index < response.Responses.Count && index < devices.Count; index++)
            {
                var sendResponse = response.Responses[index];
                if (sendResponse.IsSuccess) continue;
                var errorCode = sendResponse.Exception?.MessagingErrorCode?.ToString();
                if (errorCode is not ("Unregistered" or "SenderIdMismatch")) continue;
                devices[index].IsActive = false;
                devices[index].UpdatedAt = DateTime.UtcNow;
                changed = true;
            }
            if (changed) await _context.SaveChangesAsync(cancellationToken);
            return response.SuccessCount;
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            _logger.LogError(exception, "{UserId} kullanıcısına FCM bildirimi gönderilemedi.", userId);
            return 0;
        }
    }
}
