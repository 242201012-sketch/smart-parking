# Çevrimdışı kullanım, mobil yönetim ve iyzico kurulumu

Bu sürüm Google Cloud'a dağıtım yapmaz. Cloud Run/Firebase dosyaları ileride
kullanılmak üzere pakette durur; etkin bir Google Cloud bağlantısı kurulmamıştır.

## Mobilde yeni iş akışları

- Otopark listesi ve aktif rezervasyon uygulamanın özel SQLite alanında önbelleğe alınır.
- İnternet yokken oluşturulan rezervasyon `ONAY BEKLİYOR` olarak görünür ve bağlantı
  geldiğinde sırayla API'ye gönderilir.
- Çevrimdışı rezervasyon gerçek bir yer garantisi değildir. Sunucu onaylamadan QR
  giriş kodu üretilmez.
- Profildeki **Eşitle** düğmesi bekleyen işlem sayısını gösterir ve elle senkronizasyon yapar.
- Oturum kapatıldığında kullanıcıya ait rezervasyon önbelleği ve işlem kuyruğu temizlenir.
- Park oturumu telefondan başlatılıp bitirilebilir. Bitişte dakika bazlı ücret oluşur.
- `Admin` JWT rolü olan kullanıcı profilinden mobil yönetim panelini açabilir; doluluk,
  sensör sağlığı, sensör durumu ve yeni otopark/cihaz kaydını yönetebilir.

Ödeme, park oturumu başlatma/durdurma ve yönetim işlemleri çevrimdışı sıraya alınmaz.
Bu işlemler para, yetki veya fiziksel erişim durumunu değiştirdiği için canlı HTTPS API
doğrulaması gerektirir.

## Kart ödeme güvenlik modeli

Uygulamada kart numarası, son kullanma tarihi veya CVV alanı yoktur. API yalnızca
iyzico Checkout Form oturumu oluşturur ve mobil uygulama kullanıcıyı iyzico'nun HTTPS
sayfasına gönderir. Kart bilgileri SmartParking mobil uygulamasına, API'sine veya
veritabanına ulaşmaz.

Sanal POS ve QR ödeme aynı güvenli Checkout Form oturumunu kullanır:

- **Sanal POS:** iyzico ödeme sayfası bu telefonda/tarayıcıda açılır.
- **QR ödeme:** aynı HTTPS ödeme bağlantısı taranabilir QR olarak gösterilir; başka
  bir telefonun kamerasıyla açılabilir.
- QR kodunda kart numarası, CVV, kimlik veya fatura bilgisi bulunmaz.
- Sonuç yalnızca iyzico callback'i ve sunucu-sunucu doğrulama sonrasında `paid` olur.

Callback geldiğinde API şu değerleri iyzico'dan sunucu-sunucu tekrar sorgular:

1. Checkout token ve conversation ID;
2. `paymentStatus=SUCCESS` sonucu;
3. Ödenen tutarın sunucudaki park ücretiyle eşleşmesi;
4. Fraud durumunun onaylanması.

Yalnızca bütün kontroller geçerse `PaymentRecord.Status=paid` ve
`ParkingSession.PaymentStatus=paid` yapılır. Aynı callback tekrar gelirse işlem
idempotent biçimde zaten ödenmiş olarak döner. T.C. kimlik, telefon ve fatura adresi
checkout başlatmak için iyzico'ya iletilir; SmartParking veritabanına kaydedilmez.

## iyzico Sandbox ayarları

Önce iyzico Sandbox/merchant hesabından API Key ve Secret Key alın. API'nin callback
adresi dışarıdan erişilebilir, geçerli sertifikalı HTTPS olmalıdır. Yerel `localhost`
adresi iyzico callback'i için kullanılamaz.

`.env.example` dosyasını `.env` olarak kopyalayıp aşağıdakileri doldurun:

```dotenv
PAYMENT_PROVIDER=iyzico
IYZICO_API_KEY=SANDBOX_API_KEY
IYZICO_SECRET_KEY=SANDBOX_SECRET_KEY
IYZICO_BASE_URL=https://sandbox-api.iyzipay.com
PAYMENT_CALLBACK_BASE_URL=https://SIZIN-API-ADRESINIZ
```

Ardından API'yi yeniden başlatın. Aşağıdaki cevapta `enabled: true`,
`hostedCheckout: true`, `virtualPos: true`, `qrPayment: true` ve `sandbox: true`
görülmelidir:

```text
GET https://SIZIN-API-ADRESINIZ/api/payments/config
```

Render Blueprint kullanırken ilk dağıtımdan sonra servis URL'sini öğrenin ve şu gizli
değerleri Render Environment ekranında girin:

- `Payment__ApiKey`
- `Payment__SecretKey`
- `Payment__CallbackBaseUrl` — yalnızca origin, örn. `https://smartparking-api.onrender.com`

`render.yaml` Sandbox adresini ve `Payment__Provider=iyzico` değerini hazırlar; anahtarlar
kaynak koduna girilmez. Değerleri ekledikten sonra servisi yeniden dağıtın.

## Sandbox uçtan uca deneme

1. Gerçek kullanıcı hesabıyla giriş yapın.
2. **Profil > Park oturumları** ekranında parkı başlatıp bitirin.
3. **Ödemeler** ekranında oluşan tutarı ve otoparkı kontrol edin.
4. **Sanal POS veya QR ile öde** düğmesine basın.
5. Sanal POS için Sandbox test kartını yalnızca iyzico sayfasında girin; QR için
   kodu ikinci telefonla taratın ve aynı güvenli sayfada tamamlayın.
6. Callback sayfasından **SmartParking'e dön** bağlantısını açın.
7. Ödeme listesini yenileyip durumu `Ödendi` olarak doğrulayın.
8. Veritabanında kart numarası/CVV sütunu olmadığını ve yalnızca sağlayıcı token/reference
   tutulduğunu kontrol edin.

Canlı ödemeye geçmeden önce iyzico merchant aktivasyonu, yasal metinler/iade süreci,
webhook ile ikinci kanal mutabakatı, log maskeleme, alarm ve gerçek cihaz testleri ayrıca
tamamlanmalıdır. Bu paket bilerek Sandbox varsayılanıyla gelir.

## Android dönüş bağlantısı

Android manifesti `smartparking://payment-result` bağlantısını uygulamaya yönlendirir.
Tarayıcı dönüşünde uygulama açılır; kullanıcı **Ödemeler > Yenile** ile API'den doğrulanmış
sonucu alır. Dönüş bağlantısındaki durum yalnızca kullanıcı arayüzü içindir; ödeme kararı
her zaman API'nin iyzico sorgusuna dayanır.

## İlgili resmi belgeler

- iyzico Checkout Form başlatma: https://docs.iyzico.com/en/payment-methods/checkoutform/cf-implementation/cf-initialize
- iyzico Checkout Form ve QR ödeme: https://docs.iyzico.com/odeme-metotlari/odeme-formu
- iyzico Checkout Form sonucu sorgulama: https://docs.iyzico.com/en/payment-methods/checkoutform/cf-implementation/cf-retrieve
- iyzico resmi .NET SDK: https://github.com/iyzico/iyzipay-dotnet
- Flutter SQLite tarifi: https://docs.flutter.dev/cookbook/persistence/sqlite
