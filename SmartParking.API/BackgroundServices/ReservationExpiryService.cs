using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using SmartParking.API.Hubs;
using SmartParking.Application.Interfaces;
using SmartParking.Domain.Entities;
using SmartParking.Infrastructure.Persistence;

namespace SmartParking.API.BackgroundServices;

public sealed class ReservationExpiryService : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IHubContext<ParkingHub> _hub;
    private readonly ILogger<ReservationExpiryService> _logger;

    public ReservationExpiryService(
        IServiceScopeFactory scopeFactory,
        IHubContext<ParkingHub> hub,
        ILogger<ReservationExpiryService> logger)
    {
        _scopeFactory = scopeFactory;
        _hub = hub;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ExpireReservationsAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "Süresi dolan rezervasyonlar işlenemedi.");
            }

            await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);
        }
    }

    private async Task ExpireReservationsAsync(CancellationToken cancellationToken)
    {
        await using var scope = _scopeFactory.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var pushNotifications = scope.ServiceProvider.GetRequiredService<IPushNotificationService>();
        var now = DateTime.UtcNow;
        var expired = await context.Reservations
            .Include(item => item.ParkingSpace)
            .Where(item => item.IsActive && item.EndTime <= now)
            .ToListAsync(cancellationToken);

        if (expired.Count == 0)
            return;

        foreach (var reservation in expired)
        {
            reservation.IsActive = false;
            reservation.UpdatedAt = now;
            reservation.ParkingSpace.IsReserved = false;
            reservation.ParkingSpace.ReservedUntil = null;
            reservation.ParkingSpace.UpdatedAt = now;
            context.UserNotifications.Add(new UserNotification
            {
                UserId = reservation.UserId,
                Type = "reservation",
                Title = "Rezervasyon süresi doldu",
                Message = $"{reservation.ParkingSpace.Code} numaralı yer tekrar kullanıma açıldı."
            });
        }

        await context.SaveChangesAsync(cancellationToken);
        foreach (var parkingLotId in expired.Select(item => item.ParkingSpace.ParkingLotId).Distinct())
        {
            await _hub.Clients.All.SendAsync(
                "ParkingLotRefreshRequested",
                parkingLotId.ToString(),
                cancellationToken);
        }
        foreach (var reservation in expired)
        {
            await pushNotifications.SendToUserAsync(
                reservation.UserId,
                "Rezervasyon süresi doldu",
                $"{reservation.ParkingSpace.Code} numaralı yer tekrar kullanıma açıldı.",
                new Dictionary<string, string> { ["screen"] = "parking" },
                cancellationToken);
        }
    }
}
