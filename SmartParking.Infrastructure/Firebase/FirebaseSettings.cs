namespace SmartParking.Infrastructure.Firebase;

public sealed class FirebaseSettings
{
    public bool Enabled { get; set; }
    public string ProjectId { get; set; } = string.Empty;
    public string ServiceAccountJson { get; set; } = string.Empty;
}
