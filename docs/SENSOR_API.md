# Gerçek sensör ve kamera API'si

## Sensör cihazı hazırlama

Her cihaz önce bir yönetici tarafından kaydedilir:

```http
POST /api/admin/sensors
Authorization: Bearer ADMIN_JWT
Content-Type: application/json

{
  "parkingLotId": "OTOPARK_GUID",
  "deviceId": "AMASYA-GATEWAY-01",
  "name": "Merkez kat 1 geçidi"
}
```

İlk örnek veride `AMASYA-GATEWAY-01`, `AMASYA-GATEWAY-02` ve
`AMASYA-GATEWAY-03` cihazları hazırdır. Otopark GUID değerleri
`GET /api/parking` ile alınır.

## Doluluk olayı

```http
POST /api/sensors/readings
X-Device-Id: AMASYA-GATEWAY-01
X-Sensor-Key: RENDER_SENSOR_INGEST_KEY
Content-Type: application/json

{
  "parkingLotCode": "AMASYA-MERKEZ",
  "spaceCode": "P08",
  "isOccupied": true,
  "sequence": 1842,
  "observedAt": "2026-07-16T18:22:00Z",
  "batteryPercent": 86,
  "vehiclePlate": "05 ABC 123",
  "firmwareVersion": "1.0.0",
  "metadata": { "distanceCm": 18.4 }
}
```

`deviceId + sequence` çifti benzersizdir. Cihaz yanıt alamazsa aynı olayı aynı
sıra numarasıyla yeniden gönderebilir; API ikinci yazmayı yapmadan
`duplicate: true` döndürür. Başarılı yeni olay HTTP 202 döndürür, park alanını
günceller ve SignalR üzerinden `ParkingSpaceUpdated` ile `ParkingLotUpdated`
olaylarını yayınlar.

Saat bilgisi en fazla 5 dakika ileri ve 7 gün geride olabilir. Cihazda güvenilir
saat yoksa `observedAt` alanını göndermeyin; sunucu UTC zamanını kullanır.

## Heartbeat

```http
POST /api/sensors/heartbeat
X-Device-Id: AMASYA-GATEWAY-01
X-Sensor-Key: RENDER_SENSOR_INGEST_KEY
Content-Type: application/json

{ "batteryPercent": 86, "firmwareVersion": "1.0.0" }
```

Yönetici paneli son heartbeat beş dakikadan yeniyse cihazı çevrimiçi gösterir.
Sensör uçları cihaz başına değil servis başına dakikada 240 olayla sınırlıdır;
çok sayıda cihaz için dağıtık rate-limit katmanı eklenmelidir.

## Plaka tanıma (ANPR) webhook'u

```http
POST /api/cameras/anpr-events
X-Camera-Key: RENDER_CAMERA_WEBHOOK_KEY
Content-Type: application/json

{
  "eventId": "camera-01-20260716-001842",
  "parkingLotId": "OTOPARK_GUID",
  "cameraId": "GIRIS-KAMERA-01",
  "plateNumber": "05 ABC 123",
  "direction": "entry",
  "confidence": 0.97,
  "observedAt": "2026-07-16T18:22:00Z"
}
```

`direction` değeri `entry` veya `exit` olmalıdır. Kayıtlı bir kullanıcı plakası
eşleşirse girişte park oturumu açılır, çıkışta süre/tutar hesaplanır. Kamera veya
OCR sağlayıcısı plaka metnini üretmekten sorumludur; API ham video almaz.

## Güvenlik

- Yalnızca HTTPS Render adresini kullanın.
- Sensör ve kamera anahtarlarını firmware deposuna commit etmeyin; cihazın güvenli
  NVS/secret alanından okuyun.
- Her fiziksel ağ geçidine benzersiz `DeviceId` verin.
- Anahtar sızarsa Render'da değiştirin ve cihazları kademeli güncelleyin.
- Yönetici JWT'sini sensör cihazına koymayın.
