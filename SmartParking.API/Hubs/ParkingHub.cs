using Microsoft.AspNetCore.SignalR;

namespace SmartParking.API.Hubs;

public class ParkingHub : Hub
{
    public Task WatchParkingLot(string parkingLotId)
    {
        if (!Guid.TryParse(parkingLotId, out var parsedId))
            throw new HubException("Geçerli bir otopark kimliği gereklidir.");

        return Groups.AddToGroupAsync(Context.ConnectionId, $"parking:{parsedId}");
    }
}
