# SmartParking — Family Link ve Google Play yayın rehberi

SmartParking, Family Link denetimini aşmaya çalışmaz. Bir çocuk/gözetimli hesapta
uygulama ebeveyn tarafından engellendiyse, uygulama kodu bunu açamaz; izin ebeveyn
cihazındaki Family Link uygulamasından verilmelidir.

## Ebeveyn telefonunda izin verme

1. Family Link'i açın ve gözetilen çocuğu seçin.
2. **Ekran süresi > Uygulama sınırları > SmartParking** yolunu açın.
3. Uygulamayı **İzin verildi** durumuna getirin.
4. **Kontroller > Oturum açılan cihazlar > Uygulama izinleri** bölümünde konum,
   kamera ve bildirim izinlerini ihtiyaca göre onaylayın.
5. Ödeme yapılacaksa işlemi ebeveyn/vasiyle birlikte tamamlayın. Kart bilgileri
   SmartParking'e değil, iyzico'nun güvenli ödeme sayfasına girilir.

Resmî Google yardımı:

- Uygulamaları engelleme/izin verme: <https://support.google.com/families/answer/7103028?hl=tr>
- Uygulama izinlerini yönetme: <https://support.google.com/families/answer/10436839?hl=tr>

## Neden Google Play test dağıtımı?

Family Link, dışarıdan yüklenen APK'ları cihaz politikasına göre engelleyebilir.
Kalıcı test yolu, uygulamayı Play Console'da **Dahili test** kanalına AAB olarak
yüklemek ve gözetimli hesabı ebeveyn onayıyla test kullanıcısı yapmaktır.

1. Yetişkin geliştirici hesabıyla Play Console'da uygulama oluşturun.
2. Paket kimliğini `com.smartparking.mobile` olarak koruyun.
3. Play App Signing'i açın ve yerel upload anahtarıyla imzalanmış AAB yükleyin.
4. Hedef kitleyi gerçeğe uygun beyan edin. SmartParking çocuklara yönelik bir
   uygulama değildir; sırf Family Link görünürlüğü için çocuk yaş grubu seçmeyin.
5. Data safety formunda konum, hesap, rezervasyon/araç, bildirim ve ödeme
   faturalama akışlarını beyan edin.
6. Gizlilik politikası URL'si olarak
   `https://smartparking-amasya-2026.copper-tiger-8849.chatgpt.site/privacy`
   adresini girin.
7. Dahili test bağlantısını ebeveyn cihazında açıp gözetimli hesap için kurulumu
   onaylayın.

Google Play'in hedef kitle ve Families koşulları:

- <https://support.google.com/googleplay/android-developer/answer/9867159?hl=tr>
- <https://support.google.com/googleplay/android-developer/answer/17190352?hl=tr>

## Bu sürümdeki teknik korumalar

- `FAMILY_LINK_MODE=true` varsayılandır.
- Firebase Analytics, Crashlytics ve Performance otomatik toplaması kapalıdır.
- FCM kayıt belirteci ancak bildirim izni verildikten sonra oluşturulur.
- Google oturumu reddedilirse e-posta/şifre ve demo yolları kullanılabilir.
- Ödeme öncesi ebeveyn/vasi onayı hatırlatılır.
- Android yedeklemesi kapalıdır.
- Sürüm: `5.1.0+6`.

## Derleme

```powershell
.\build-android.ps1 -ApiBaseUrl "https://smartparking-api-x1xp.onrender.com" -FamilyLinkMode $true
```

`android/key.properties` varsa betik hem APK hem Google Play için AAB üretir.
Yoksa güvenli upload anahtarı oluşturulup bu dosya yerelde yapılandırılmalıdır;
anahtar ve parolalar Git'e eklenmemelidir.
