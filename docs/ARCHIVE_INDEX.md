# Arşiv Endeksi (Projects-Arsiv)

Bu dosya, git'e giremeyen büyük klasörlerin nerede durduğunu ve
ana repo (`main`) ile ilişkisini belgeler. Arşiv iki yerdedir:

- Yerel: `C:\dev\smartparking\Projects-Arsiv\` (git dışı, `.gitignore`)
- Yedek: `OneDrive\Documents\SMART PARKİNG\Projects-Arsiv\`

Her iki konum da dosya sayısı + bayt olarak doğrulanmıştır (Eylül 2026).

## Ana repoda ZATEN olanlar (kanıtlı, ek işlem yok)

| Kaynak | Repo konumu | Doğrulama |
|---|---|---|
| ESP32 firmware (`SmartParkingSensor.ino`) | `sensor-examples/esp32-http/` | Bayt-birebir, initial commit'ten beri |
| GPU deploy (`docker-compose.gpu.yml`, `setup-ubuntu-gpu.sh`) | `deploy/ubuntu-gpu/` | Bayt-birebir, initial commit'ten beri |

Firmware, `/api/sensors/readings` ile uyumludur: `X-Device-Id` /
`X-Sensor-Key` başlıkları, `parkingLotCode` + `spaceCode` + `sequence`
(ilk gönderim 1'den başlar, `sequence > 0` kuralına uyar), `firmwareVersion`.
Ayrıntılar: `docs/SENSOR_API.md`.

## Yalnızca arşivde duranlar (repoya alınmaz)

| Klasör | Boyut | İçerik notu |
|---|---|---|
| SmartParkingApiRelease | ~3,8 GB | Derlenmiş API sürümü |
| SmartParkingBuild | ~3,8 GB | Derleme çıktısı |
| SmartParkingBuildCodex | ~2,4 GB | Derleme çıktısı (Codex) |
| SmartParkingArduinoCli | ~448 MB | `arduino-cli` aracı (ikili dosya, proje değil) |
| SmartParkingTwinmotion | ~47 MB | Twinmotion sahnesi (tek dosya) |
| SmartParkingUnreal | ~12,6 GB | Tam Unreal Engine projesi (`Content/`, `Source/`, `Config/`) |
| SmartParkingV740Test | ~3,6 GB | Test çıktısı |
| SmartParkingV750Test | ~2,3 GB | Test çıktısı |
| SmartParkingWEB | ~5,9 GB | **Web arayüzü içermez.** Eski mobil+backend snapshot'ları (`_SmartParking_V440..V560_YEDEK_*`) + Flutter/Android derleme artifaktları |

## Karar notları

- `SmartParkingWEB` adına rağmen içinde web frontend yoktur; `web/`
  klasörü repoda bilinçli olarak boştur. Gerçek bir web istemcisi
  gerektiğinde sıfırdan (API + SignalR hub üzerinden) yazılmalıdır.
- Unreal/Twinmotion dünyası bağımsız ilerler; API ile bir sözleşmesi
  yoktur. Entegrasyon istenirse önce hub olaylarının (`ParkingSpaceUpdated`,
  `AnprEventReceived`) UE tarafında tüketilmesi gerekir.
- Arşive yeni ekleme yapılırsa bu dosyadaki tablo güncellenmelidir.
