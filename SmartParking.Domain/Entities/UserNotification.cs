using SmartParking.Domain.Common;

namespace SmartParking.Domain.Entities;

public class UserNotification : BaseEntity
{
    public Guid UserId { get; set; }
    public string Type { get; set; } = "info";
    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public bool IsRead { get; set; }
    public string? ActionUrl { get; set; }
}
