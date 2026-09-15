# SmartParking Türkiye — mobil, API ve gerçek sensör paketi

Bu çözüm 81 ili kapsayan Flutter Android uygulaması, ASP.NET Core 10 LTS API,
PostgreSQL, Google Cloud Run/Cloud SQL, Render yedek dağıtımı, iyzico ve fiziksel
sensör örneklerini birlikte içerir. Birincil üretim hedefi Google Cloud, geçiş
sırasında çalışan geri dönüş hedefi Render'dır.

## Birleşik canlı sürüm

- Web: `https://smartparking-amasya-2026.copper-tiger-8849.chatgpt.site`
- Ortak API: `https://smartparking-api-x1xp.onrender.com`
- Android paket kimliği: `com.smartparking.mobile`
- Android sürümü: `5.2.0+7` (Family Link, sanal POS ve QR ödeme)
- Hazır APK: `release/SmartParking-Turkiye-Pos-QR-v7.apk`
- Web kaynağı: `web/`

Web ve Android aynı API, kullanıcı hesabı, rezervasyon, favori, bildirim,
park geçmişi ve iyzico ödeme kayıtlarını kullanır.

## Eklenen üretim özellikleri

- PostgreSQL ve SQL Server arasında ortam ayarıyla seçim
- Ücretsiz test planına sabitlenmiş Render Docker Web Service + PostgreSQL için `render.yaml`
- HTTP/JSON gerçek sensör alımı, cihaz kaydı, heartbeat, pil/firmware sağlığı
- `DeviceId + sequence` idempotency ve sensör rate limit'i
- SignalR ile canlı otopark/alan güncellemeleri ve otomatik yeniden bağlantı
- Süreli, özellik tercihli gerçek rezervasyon; QR token ve yönetici doğrulaması
- Favoriler, uygulama içi bildirimler, araçlar ve kullanıcı profili
- Türkiye'nin 81 ili için il bazlı otopark keşfi, arama ve en yakın otopark
- Park oturumu/geçmişi, dakika bazlı ücret ve kartla ödeme
- Telefondan park oturumu başlatma/bitirme ve ödenecek tutara doğrudan geçiş
- iyzico Checkout Form ile Sandbox-hazır kredi kartı ödeme akışı
- iyzico hosted sanal POS ve başka cihazdan taranabilir QR ödeme akışı
- Kart/CVV toplamayan hosted ödeme, callback'te token/tutar/fraud doğrulaması
- SQLite çevrimdışı önbellek ve bağlantı gelince rezervasyon senkronizasyon kuyruğu
- JWT rolüyle korunan mobil yönetim paneli
- ANPR/plaka tanıma webhook'u ile otomatik giriş/çıkış kaydı
- Yönetici özeti, sensör çevrimiçi/pil durumu ve yeni otopark/cihaz oluşturma
- EV şarj, erişilebilir alan, kapalı otopark ve saatlik ücret alanları
- Güvenli CORS origin listesi, JWT roller, rate limit, HSTS ve sağlık kontrolü
- Google Maps üzerinde canlı doluluk işaretleri, en yakın otopark ve yol tarifi
- Firebase Google girişi, FCM push, Analytics, Crashlytics ve Performance
- Firebase Admin ile doğrulanmış ID tokenı ve kullanıcıya özel cihaz bildirimleri
- Family Link uyumlu veri toplama, isteğe bağlı Google girişi ve ebeveyn ödeme onayı
- GitHub Actions ile Render API derleme ve test kontrolü

Kartla ödeme sağlayıcısı varsayılan olarak kapalıdır. iyzico adaptörü ve mobil
ödeme ekranı eklenmiştir; gerçek işlem için Sandbox/merchant API anahtarları ve
dışarıdan erişilebilir HTTPS callback adresi gerekir. Kart bilgileri uygulama/API
tarafından toplanmaz veya saklanmaz. Kurulum: [`docs/OFFLINE_ADMIN_IYZICO.md`](docs/OFFLINE_ADMIN_IYZICO.md)

Render üretim kontrol listesi: [`docs/RENDER_PRODUCTION_CHECKLIST.md`](docs/RENDER_PRODUCTION_CHECKLIST.md)

Family Link ve Google Play yayın rehberi: [`docs/FAMILY_LINK_PLAY_RELEASE.md`](docs/FAMILY_LINK_PLAY_RELEASE.md)

## Proje yapısı

```text
lib/                         Flutter mobil uygulaması
android/                     Android uygulama ayarları
SmartParking.API/            ASP.NET Core Web API ve SignalR
SmartParking.Application/    Uygulama sözleşmeleri
SmartParking.Domain/         Alan modelleri
SmartParking.Infrastructure/ EF Core, Identity, SQLite/PostgreSQL/SQL Server
SmartParking.Tests/          Backend testleri
docs/                        Render ve sensör kurulum rehberleri
google-cloud/                Google Cloud altyapı hazırlama betiği
cloudbuild.yaml              Cloud Build/Cloud Run dağıtımı
sensor-examples/             Node simülatörü ve ESP32 örneği
render.yaml                  Render Blueprint
docker-compose.yml           Yerel PostgreSQL + API
```

## En hızlı yerel başlatma

Visual Studio ile `SmartParking.API` başlangıç projesini çalıştırdığınızda
geliştirme ortamı harici SQL Server gerektirmeyen yerel SQLite veritabanını
otomatik oluşturur ve tarayıcıda Swagger'ı açar. Komut satırı karşılığı:

```powershell
dotnet run --project .\SmartParking.API\SmartParking.API.csproj
```

Docker ile PostgreSQL kullanmak isterseniz aşağıdaki akışı uygulayın.

Docker Desktop kuruluysa kök klasörde `.env.example` dosyasını `.env` adıyla
kopyalayın, parolaları değiştirin ve çalıştırın:

```powershell
docker compose up --build
```

API adresleri:

- `http://localhost:58278/health`
- `http://localhost:58278/api/parking`
- geliştirme Swagger: `http://localhost:58278/swagger`

İlk boş PostgreSQL veritabanında tablolar ve 81 il merkezini kapsayan örnek
otopark verileri otomatik oluşturulur. Mevcut Amasya pilot verileri korunur ve
ulusal veriyle tamamlanır. Yerel volume'u daha sonra silmeden şema değiştirecekseniz EF Core
PostgreSQL migration üretin.

## Render'a dağıtma

Ayrıntılı adımlar: [`docs/RENDER_KURULUM.md`](docs/RENDER_KURULUM.md)

GitHub CLI ile giriş yaptıktan sonra projeyi `smartparking-amasya` adlı özel
depoya güvenli biçimde göndermek için proje kökünde çalıştırın:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\publish-private-github.ps1
```

Betik yerel Git deposunu oluşturur, gizli yerel yapılandırmaların commit'e
girmediğini denetler, ilk commit'i hazırlar ve özel depoyu oluşturup gönderir.

Özetle bu klasörü özel GitHub/GitLab/Bitbucket deposuna gönderin, Render'da
**New > Blueprint** ile `render.yaml` dosyasını seçin ve istenen sensör, kamera,
yönetici gizli değerlerini girin. Son oluşan HTTPS API adresi PWA içindeki
**Altyapı > API ayarları** ekranına veya Flutter derlemesine verilir.

Blueprint ilk test için ücretsiz web servis ve ücretsiz PostgreSQL oluşturur.
Ödeme sağlayıcısı ilk dağıtımda kapalıdır; Render URL'si ve iyzico Sandbox
anahtarları hazır olduğunda ortam değişkenleriyle etkinleştirilir.

## Google Cloud ve Firebase'e dağıtma

Android/Firebase kaydı, Maps anahtarı, Cloud SQL ve tek komutlu Cloud Run
dağıtımı: [`docs/GOOGLE_CLOUD_FIREBASE.md`](docs/GOOGLE_CLOUD_FIREBASE.md)

## Gerçek sensör bağlama

Tam sözleşme ve cURL örnekleri: [`docs/SENSOR_API.md`](docs/SENSOR_API.md)

Render API'yi bir fiziksel cihaz olmadan sınamak için:

```powershell
node .\sensor-examples\simulator.mjs `
  --api=https://SIZIN-SERVISINIZ.onrender.com `
  --device=AMASYA-GATEWAY-01 `
  --key=RENDER_SENSOR_INGEST_KEY `
  --lot=AMASYA-MERKEZ `
  --space=P08 `
  --occupied=true
```

ESP32 + HC-SR04 örneği `sensor-examples/esp32-http/SmartParkingSensor.ino`
dosyasındadır. Wi-Fi, API, anahtar ve kök CA değerlerini cihaz güvenli kurulum
sürecinden sağlayın. Sensör değişiklikleri üç ardışık ölçümle filtrelenir ve
başarısız gönderimler aynı sıra numarasıyla tekrar denenir.

## Flutter uygulamasını çalıştırma

Gerekenler: Flutter stable, Android Studio/SDK ve JDK. İlk kez:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup-mobile.ps1
```

Bu komut güncel Flutter/Firebase bağımlılıklarını çözer ve `pubspec.lock`
dosyasını kullandığınız Flutter stable sürümüne göre oluşturur.

Android emülatöründe yerel API için:

```powershell
.\run-android.ps1
```

Gerçek telefon veya Render API için:

```powershell
.\run-android.ps1 -ApiBaseUrl "https://SIZIN-SERVISINIZ.onrender.com"
```

Google Maps + Firebase destekli release APK:

```powershell
.\build-android.ps1 `
  -ApiBaseUrl "https://API_ADRESINIZ.run.app" `
  -MapsApiKey "ANDROID_MAPS_API_KEY" `
  -GoogleWebClientId "FIREBASE_WEB_CLIENT_ID.apps.googleusercontent.com"
```

APK `build\app\outputs\flutter-apk\app-release.apk` altında oluşur. Play Store
dağıtımı öncesinde size ait Android release imza anahtarı tanımlanmalıdır.

## Önemli ortam değişkenleri

| Değişken | Amaç |
|---|---|
| `ConnectionStrings__DefaultConnection` | SQLite/PostgreSQL/SQL Server bağlantısı |
| `Database__Provider` | `SQLite`, `PostgreSQL` veya `SqlServer` |
| `Jwt__Key` | En az 32 karakter JWT imza anahtarı |
| `Cors__AllowedOrigins__0` | Web/PWA origin adresi |
| `Sensor__IngestKey` | Sensör HTTP anahtarı |
| `Camera__WebhookKey` | ANPR webhook anahtarı |
| `Admin__Email`, `Admin__Password` | İlk yönetici hesabı |
| `Payment__Provider` | `disabled`, `manual` veya `iyzico` |
| `Payment__ApiKey`, `Payment__SecretKey` | iyzico Sandbox/merchant gizli anahtarları |
| `Payment__BaseUrl` | Varsayılan `https://sandbox-api.iyzipay.com` |
| `Payment__CallbackBaseUrl` | Dışarıdan erişilebilir HTTPS API origin'i |
| `Firebase__Enabled` | Firebase Admin/FCM anahtarı |
| `Firebase__ProjectId` | Firebase/Google Cloud proje kimliği |
| `Firebase__ServiceAccountJson` | Yalnızca ADC olmayan ortamlar için gizli JSON |

Gizli değerleri Git'e veya mobil uygulama kaynak koduna yazmayın.

> Google Cloud bağlantısı bu aşamada duraklatılmıştır. Cloud dosyaları hazırdır,
> ancak bu sürüm herhangi bir Google Cloud hesabına dağıtım yapmaz.
