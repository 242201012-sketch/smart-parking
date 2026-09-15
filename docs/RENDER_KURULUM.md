# Render kurulumu

Bu paket, `render.yaml` Blueprint dosyasıyla tek seferde bir Docker Web Service
ve yalnızca Render iç ağından erişilen PostgreSQL veritabanı oluşturur. Her iki
kaynak da ilk doğrulama için Render'ın `free` planına sabitlenmiştir.

Ücretsiz web servisi kullanılmadığında uykuya geçebilir; ilk istek bu nedenle
yavaş yanıt verebilir. Ücretsiz PostgreSQL geçici test içindir, süre/yedekleme
sınırları nedeniyle üretim verisi için kullanılmamalıdır.

## 1. Kaynak kodu Git sağlayıcısına gönderin

Render otomatik dağıtım için GitHub, GitLab veya Bitbucket deposuna bağlanır.
Bu klasörü özel bir depoya gönderin; `render.yaml` depo kökünde kalmalıdır.

## 2. Blueprint oluşturun

Render Dashboard içinde **New > Blueprint** seçin, depoyu bağlayın ve
`render.yaml` dosyasını onaylayın. Bölge `frankfurt`, API sağlık kontrolü
`/health`, veritabanı ise dış IP erişimine kapalı olarak ayarlanmıştır.

Kurulum ekranı şu gizli değerleri ister:

- `Sensor__IngestKey`: en az 32 rastgele karakter;
- `Camera__WebhookKey`: en az 32 rastgele karakter;
- `Admin__Email`: ilk yönetici hesabı;
- `Admin__Password`: en az 12 karakterlik güçlü yönetici parolası;
- `Firebase__ProjectId` ve `Firebase__ServiceAccountJson`: bu aşamada isteğe bağlıdır;
  Google Cloud/Firebase bağlantısı duraklatıldığı için `Firebase__Enabled=false` gelir.

`Jwt__Key` Render tarafından otomatik üretilir. Gizli değerleri kaynak koda
yazmayın.

İlk ücretsiz dağıtımda `Payment__Provider=disabled` gelir. API adresi
oluştuktan ve iyzico Sandbox anahtarları hazırlandıktan sonra Render ortamına
`Payment__ApiKey`, `Payment__SecretKey` ve `Payment__CallbackBaseUrl` ekleyip
`Payment__Provider=iyzico` yapabilirsiniz. Ödeme kodu ve mobil akış pakette
hazır kalır.

## 3. İlk çalışmayı doğrulayın

Dağıtım tamamlanınca aşağıdaki uçların HTTP 200 döndürdüğünü kontrol edin:

```text
https://SIZIN-SERVISINIZ.onrender.com/health
https://SIZIN-SERVISINIZ.onrender.com/api/parking
```

İlk boş PostgreSQL veritabanında `Database__UseEnsureCreated=true` tüm Identity,
otopark, rezervasyon, sensör, FCM cihazı ve geçmiş tablolarını oluşturur; üç
Amasya otoparkı ile örnek cihazları ekler. Bu sürüm eski Render veritabanlarında
`PushDevices` tablosunu idempotent biçimde tamamlar. Sonraki şema değişikliklerinde üretim verisini
korumak için sürümlü PostgreSQL migration oluşturulmalı ve bu seçenek kapatılmalıdır.

## 4. Web/PWA uygulamasını bağlayın

SmartParking sitesinde **Altyapı > dişli simgesi** yolunu açın ve Render servis
adresini girin. Adres HTTPS olmalıdır. PWA aynı anda otopark listesini API'den
çeker ve `/hubs/parking` SignalR kanalına bağlanır.

Dağıtılan web alan adı değişirse Render ortamındaki
`Cors__AllowedOrigins__0` değerini yeni origin ile güncelleyin.

## 5. Üretim kontrol listesi

- Gerçek kullanıma geçmeden önce ücretsiz servis ve geçici PostgreSQL'i kalıcı,
  yedeklemeli planlara taşıyın.
- Yönetici parolasını ilk girişten sonra parola yöneticisinde saklayın.
- Sensör ve kamera anahtarlarını cihaz grubu değiştiğinde döndürün.
- Render loglarında `/health`, sensör 401/429 ve veritabanı hataları için alarm kurun.
- Kartla ödeme için önce Sandbox doğrulamasını tamamlayın. iyzico adaptörü
  hazırdır; kart bilgileri API'ye gelmez. Ayrıntılar:
  [`OFFLINE_ADMIN_IYZICO.md`](OFFLINE_ADMIN_IYZICO.md).
