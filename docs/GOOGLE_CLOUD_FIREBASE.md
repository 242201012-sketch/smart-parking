# Google Cloud + Firebase + Android kurulum rehberi

Bu sürüm Google Maps SDK for Android, Google ile giriş, Firebase Cloud
Messaging, Analytics, Crashlytics, Performance Monitoring, Firebase Admin,
Cloud Run, Cloud SQL for PostgreSQL, Secret Manager ve Cloud Build desteğini
hazır olarak içerir. Kaynak koda gerçek API anahtarı veya servis hesabı
eklenmez.

## 1. Google Cloud ve Firebase projesi

1. Faturalandırması açık bir Google Cloud projesi oluşturun ve **Project ID**
   değerini not edin.
2. Aynı projeyi [Firebase Console](https://console.firebase.google.com/) içinde
   **Add project > Use an existing Google Cloud project** ile Firebase'e ekleyin.
3. Firebase Authentication içinde **Google** sağlayıcısını etkinleştirin ve
   destek e-posta adresini seçin.
4. Firebase proje ayarlarında Google Analytics'i bağlayın. Crashlytics,
   Performance ve Cloud Messaging aynı Android uygulama kaydını kullanacaktır.

## 2. Android uygulamasını Firebase'e kaydetme

1. Firebase proje ayarlarında Android uygulaması ekleyin.
2. Paket adı tam olarak `com.smartparking.mobile` olmalıdır.
3. Debug ve release imza sertifikalarınızın SHA-1 ve SHA-256 parmak izlerini
   ekleyin. Debug parmak izini almak için Android klasöründe
   `gradlew signingReport` çalıştırabilirsiniz.
4. İndirilen `google-services.json` dosyasını
   `android/app/google-services.json` konumuna koyun. Bu dosya pakete dahil
   edilmez; sizin Firebase projenize özeldir.
5. Firebase Authentication > Settings > Authorized domains bölümünü web/PWA
   alan adınız için kontrol edin.

Uygulama `google-services.json` varsa Firebase Gradle eklentilerini otomatik
etkinleştirir. Dosya yoksa uygulamanın Firebase dışındaki işlevleri çalışmaya
devam eder; Google girişi, push, Analytics ve Crashlytics pasif kalır.

## 3. Google Maps anahtarı

Google Cloud Console'da **Maps SDK for Android** API'sini açın ve bir API
anahtarı oluşturun. Anahtarı şu iki kısıtla sınırlandırın:

- Application restriction: **Android apps**
- Paket: `com.smartparking.mobile`, sertifika: release SHA-1
- API restriction: yalnızca **Maps SDK for Android**

Anahtarı kaynak koda yazmayın. Önce `setup-mobile.ps1` ile Flutter'ın
`android/local.properties` dosyasını oluşturun; ardından bu dosyaya
`MAPS_API_KEY=...` satırını ekleyebilirsiniz. `local.properties` Git'ten
hariç tutulur. `local.defaults.properties` yalnızca anahtarsız derlemelerde
Gradle için güvenli bir yer tutucudur; `local.properties` üzerine kopyalamayın.

Önerilen yöntem anahtarı derleme betiğine vermektir:

```powershell
.\build-android.ps1 `
  -ApiBaseUrl "https://API_ADRESINIZ.run.app" `
  -MapsApiKey "SIZIN_ANDROID_MAPS_ANAHTARINIZ" `
  -GoogleWebClientId "FIREBASE_WEB_CLIENT_ID.apps.googleusercontent.com"
```

## 4. Cloud altyapısını hazırlama

Google Cloud CLI ve OpenSSL kurulu bir Bash terminalinde:

```bash
gcloud auth login
chmod +x google-cloud/bootstrap.sh
./google-cloud/bootstrap.sh GOOGLE_CLOUD_PROJECT_ID europe-west3
```

Betik şunları oluşturur:

- `smartparking` Artifact Registry deposu
- `smartparking-runtime` Cloud Run servis hesabı
- PostgreSQL 16 `smartparking-db` Cloud SQL örneği ve uygulama kullanıcısı
- Veritabanı, JWT, sensör, kamera ve ilk yönetici sırları
- Cloud SQL Client, Secret Manager Accessor ve FCM Admin yetkileri
- Cloud Build'in Cloud Run'a dağıtım yetkileri

Betik yeniden çalıştırıldığında mevcut sırları, veritabanı parolasını ve iyzico
Sandbox anahtarlarını korur;
gereksiz anahtar döndürmez. Anahtar döndürme işlemini Secret Manager'da yeni
bir sürüm oluşturarak planlı biçimde yapın.

Cloud SQL ücretli bir kaynaktır. Bölge ve makine sınıfını üretim yükünüze göre
`google-cloud/bootstrap.sh` içinde değiştirebilirsiniz.

Betik `gcloud builds get-default-service-account` ile projenizin gerçekten
kullandığı Cloud Build hesabını bulur. Google'ın yeni projelerde kullanabildiği
Compute Engine varsayılan hesabı ile eski Cloud Build hesabını bu nedenle
karıştırmaz. Kuruluş politikanız IAM değişikliklerini engellerse aynı rolleri
Cloud Build **Settings > Permissions** ekranında bir yöneticinin vermesi gerekir.

## 5. Cloud Run'a dağıtma

Kök klasörde:

```bash
gcloud builds submit --config=cloudbuild.yaml .
```

Farklı web origin'i veya bölge için:

```bash
gcloud builds submit \
  --config=cloudbuild.yaml \
  --substitutions=_REGION=europe-west3,_CORS_ORIGIN=https://uygulamaniz.example \
  .
```

`cloudbuild.yaml` Docker imajını Artifact Registry'ye yollar, Cloud Run'a
dağıtır, Cloud SQL örneğini bağlar ve gizli değerleri Secret Manager'dan
çalışma anında enjekte eder. Cloud Run üzerinde Firebase Admin servis hesabı
JSON'u gerekmez; Application Default Credentials kullanılır.

Varsayılan dağıtım, maliyeti sınırlamak için minimum örnek sayısını `0`, maksimum
örnek sayısını `1` ve CPU kullanımını istek bazlı ayarlar. İlk istek soğuk
başlatma nedeniyle gecikebilir. Kesintisiz arka plan görevleri gereken üretim
ortamında `_MIN_INSTANCES=1` kullanılabilir; bu ayar sürekli ücret doğurur.
Çoklu örneğe ölçeklemeden önce SignalR için dağıtık bir backplane ekleyin.

Kart ödemesi iyzico Sandbox hosted checkout ile çalışır. API ve gizli anahtarlar
`smartparking-iyzico-api-key` ve `smartparking-iyzico-secret-key` Secret Manager
sırlarında tutulur. Callback adresi Cloud Run'ın deterministik HTTPS adresinden
otomatik oluşturulur; kart numarası ve CVV SmartParking sunucusuna gelmez.

Dağıtım sonrası kontrol:

```bash
SERVICE_URL="$(gcloud run services describe smartparking-api \
  --region=europe-west3 --format='value(status.url)')"
curl "$SERVICE_URL/health"
curl "$SERVICE_URL/"
```

## 6. APK oluşturma ve telefona kurma

Flutter stable, Android Studio/SDK, JDK 17 ve Android SDK 36 kurulu olmalıdır.

```powershell
powershell -ExecutionPolicy Bypass -File .\setup-mobile.ps1
.\build-android.ps1 `
  -ApiBaseUrl "https://API_ADRESINIZ.run.app" `
  -MapsApiKey "SIZIN_ANDROID_MAPS_ANAHTARINIZ" `
  -GoogleWebClientId "FIREBASE_WEB_CLIENT_ID.apps.googleusercontent.com"
```

APK: `build/app/outputs/flutter-apk/app-release.apk`

Play Store için `android/key.properties.example` dosyasını
`android/key.properties` olarak kopyalayın, kendi upload keystore bilgilerinizi
girin ve keystore'u güvenli biçimde saklayın.

## 7. Uçtan uca test listesi

- Google hesabıyla giriş ve SmartParking JWT alınması
- Harita ekranında otopark işaretleri ve yol tarifi
- Android 13+ bildirim izni ve `/api/devices/push/status` cihaz sayısı
- Rezervasyon oluşturma/iptal, oturum giriş/çıkış ve ödeme FCM bildirimi
- Firebase Analytics DebugView olayları
- Crashlytics test hatasının konsolda görünmesi
- Cloud Run `/health` yanıtı ve Cloud SQL'de `PushDevices` tablosu
- Geçersiz FCM tokenlarının backend tarafından otomatik pasifleştirilmesi

## Güvenlik notları

- `google-services.json`, `local.properties`, keystore ve servis hesabı JSON'u
  Git'e eklenmez.
- Mobil istemciye yalnızca Android uygulamasıyla kısıtlı Maps anahtarı konur.
- Backend sırları Secret Manager'dadır; Cloud Run servis hesabına yalnızca
  gerekli roller verilir.
- FCM tokenları uzunluk varsayımına bağlı kalmadan saklanır; benzersizlik
  denetimi tokenın SHA-256 özeti üzerinden yapılır.
- Render kullanılırsa ADC olmadığı için `Firebase__ServiceAccountJson` gizli
  ortam değişkenine tek satırlık servis hesabı JSON'u girilmelidir.
