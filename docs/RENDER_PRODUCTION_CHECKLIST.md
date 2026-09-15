# SmartParking Render üretim kontrol listesi

Bu kontrol listesi Render + PostgreSQL + iyzico dağıtımı içindir. Google Cloud,
Cloud Run ve Cloud SQL bu yayının parçası değildir.

## Render gizli değişkenleri

`render.yaml` Blueprint kurulurken aşağıdaki değerleri Render panelinden girin.
Değerleri GitHub'a, ZIP dosyasına veya `.env` dosyasına yazmayın.

- `Sensor__IngestKey`: en az 32 karakterlik rastgele sensör anahtarı
- `Camera__WebhookKey`: sensör anahtarından farklı, en az 32 karakterlik anahtar
- `Admin__Email`: ilk yönetici hesabının e-posta adresi
- `Admin__Password`: benzersiz ve güçlü yönetici parolası
- `Payment__ApiKey`: iyzico Sandbox veya canlı mağaza API anahtarı
- `Payment__SecretKey`: aynı iyzico ortamına ait gizli anahtar

`Jwt__Key` Blueprint tarafından otomatik ve gizli üretilir. PostgreSQL bağlantı
dizesi de Render veritabanından otomatik alınır.

## Sabit üretim ayarları

- Web origin: `https://smartparking-amasya-2026.copper-tiger-8849.chatgpt.site`
- API: `https://smartparking-api-x1xp.onrender.com`
- iyzico callback: `https://smartparking-api-x1xp.onrender.com/api/payments/iyzico/callback`
- Mobil dönüş bağlantısı: `smartparking://payment-result`
- Para birimi: `TRY`

Sandbox testleri bittikten ve iyzico mağaza onayı alındıktan sonra
`Payment__BaseUrl` canlı iyzico adresine geçirilmeli, canlı anahtarlar ayrıca
tanımlanmalıdır. Sandbox anahtarları canlı ortam anahtarlarıyla karıştırılmamalıdır.

## Yayın sonrası kontrol

1. `/health` yanıtının başarılı olduğunu doğrulayın.
2. `/` yanıtında API sürümünün `5.0` olduğunu kontrol edin.
3. `/api/parking` listesinin en az 81 ili kapsadığını kontrol edin.
4. `/api/payments/config` yanıtında iyzico, hosted checkout ve doğru
   Sandbox/canlı ortam değerlerini kontrol edin.
5. Web sitesinden yeni hesap açma, giriş, rezervasyon ve tamamlanmış park
   oturumu akışını test edin.
6. iyzico test kartıyla ödemeyi tamamlayıp park oturumunun `paid` durumuna
   geçtiğini doğrulayın.
7. Android uygulamasında aynı hesabın rezervasyon ve ödeme geçmişini
   gösterdiğini kontrol edin.

## Operasyon

- Render ücretsiz servis uykuya girebilir; ilk istek gecikebilir.
- PostgreSQL yedekleme ve saklama süresini üretim trafiğinden önce ayrıca planlayın.
- iyzico, yönetici, sensör ve kamera anahtarlarını düzenli aralıklarla yenileyin.
- Anahtarları ekran görüntüsü, destek mesajı veya GitHub issue içinde paylaşmayın.
