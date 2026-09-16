# Unreal / Harici Tüketici Entegrasyon Sözleşmesi

`SmartParkingUnreal` (12,6 GB) ve Twinmotion sahnesi bağımsız dünyalardır;
repoda Unreal eklentisi yoktur. Canlı veri almak isteyen her harici tüketici
(Unreal, Twinmotion canlı bağlantı, özel pano) aşağıdaki sözleşmeyi kullanır.

## Bağlantı

- Hub URL: `http(s)://<api-host>/hubs/parking` (SignalR, JSON protokolü)
- Kimlik doğrulama: **hub şu an anonimdir** (`ParkingHub` üzerinde
  `[Authorize]` yoktur). JWT yine de `accessTokenFactory` ile gönderilmelidir;
  hub'a auth eklendiğinde istemciler etkilenmez.
- REST tabanı: `http(s)://<api-host>/api` (telemetri uçları `[Authorize]` +
  `dashboard` rate limiti ister).

## Olaylar (server → client)

| Olay | Argümanlar | Kaynak |
|---|---|---|
| `ParkingSpaceUpdated` | `{ parkingLotId, parkingSpaceId, spaceCode, isOccupied, isReserved, availableCapacity, totalCapacity, updatedAt }` | Sensör okuması (`POST /api/sensors/readings`) |
| `ParkingStatusUpdated` | `(parkingLotId: string, hasAvailable: bool)` | Sensör okuması |
| `ParkingLotUpdated` | `{ id, name, address, latitude, longitude, totalCapacity, availableCapacity, zone, hourlyRate, hasElectricCharging, hasAccessibleSpaces, isCovered, ... }` (tam lot snapshot) | Sensör okuması |
| `AnprEventReceived` | `{ id, parkingLotId, plateNumber, direction, observedAt }` | Kamera olayı (`POST /api/cameras/anpr-events`, `recognize`) |
| `ParkingLotRefreshRequested` | `(parkingLotId: string)` | Rezervasyon açılışı/kapanışı/süre sonu |

Tüm GUID ve zaman alanları string'dir (`observedAt` ISO-8601 UTC).
İstemci, ilgilendiği `parkingLotId` dışındaki olayları göz ardı etmelidir.

## Örnek tüketici (JavaScript, @microsoft/signalr)

```js
const connection = new signalR.HubConnectionBuilder()
  .withUrl("https://<api-host>/hubs/parking", {
    accessTokenFactory: () => "<JWT>",
  })
  .withAutomaticReconnect()
  .build();

const LOT_ID = "<parking-lot-guid>";

connection.on("ParkingSpaceUpdated", (update) => {
  if (update.parkingLotId !== LOT_ID) return;
  // update.spaceCode, update.isOccupied, update.availableCapacity ...
});

connection.on("AnprEventReceived", (event) => {
  if (event.parkingLotId !== LOT_ID) return;
  // event.plateNumber, event.direction ("entry" | "exit"), event.observedAt
});

connection.on("ParkingLotRefreshRequested", (lotId) => {
  if (lotId !== LOT_ID) return;
  // REST'ten tam görünümü yeniden çek: GET /api/dashboard/{lotId}/...
});

await connection.start();
```

REST uçlarının tam listesi için `docs/SENSOR_API.md` ve
`SmartParking.API/Controllers/DashboardController.cs` dosyasına bakın.

## Twinmotion notu

Twinmotion sahnesi (`Projects-Arsiv/SmartParkingTwinmotion`) statik bir
dosyadır; canlı veri akışı yoktur. Canlı senaryo için Unreal tarafında
yukarıdaki hub sözleşmesini tüketen bir istemci yazılmalıdır.
