# SmartParking Türkiye v5 — Render yayını

Bu teslim paketi Google Cloud kullanmaz. Üretim altyapısı Render Web Service,
Render PostgreSQL ve iyzico hosted checkout akışına göre hazırlanmıştır.

## Pakette bulunanlar

- `api-mobile-source`: Türkiye genelini kapsayan API ve Android/Flutter kaynakları
- `web-source`: canlı web sitesinin kaynakları
- `android/SmartParking-Turkiye-v5.apk`: telefona kurulabilir Android paketi
- API kaynağındaki `docs/RENDER_PRODUCTION_CHECKLIST.md`: yayın ve gizli anahtar kontrol listesi

## Canlı adresler

- Web: https://smartparking-amasya-2026.copper-tiger-8849.chatgpt.site
- API: https://smartparking-api-x1xp.onrender.com

API değişiklikleri GitHub ana dalına birleştirilip Render tarafından yeniden
yayınlanana kadar canlı API eski sürümü göstermeye devam eder.

Kart numarası, CVV, iyzico gizli anahtarı, yönetici parolası veya cihaz anahtarları
ZIP dosyasına ve GitHub'a eklenmemiştir. Bunlar yalnızca Render'ın gizli ortam
değişkenleri alanına girilmelidir.
