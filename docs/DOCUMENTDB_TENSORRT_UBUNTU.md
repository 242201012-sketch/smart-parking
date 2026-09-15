# DocumentDB + TensorRT + Ubuntu GPU entegrasyonu

Bu rehber SmartParking API'sini üç yeni bileşene bağlar:

| Bileşen | Rol |
|---|---|
| **AWS DocumentDB** (MongoDB uyumlu) | Yüksek hacimli sensör okumaları ve ANPR olayları telemetri deposu |
| **TensorRT (NVIDIA GPU)** | Plaka tanıma inference'ı — `AI/anpr-tensorrt` servisi |
| **GPU'lu Ubuntu** | Tek ana makinede API + ANPR + PostgreSQL yığını |

## 1. DocumentDB telemetri deposu

Infrastructure katmanına `MongoDB.Driver 3.11` eklendi. `ITelemetryStore`
arayüzü iki uçla yazılır:

- `MongoTelemetryStore` — AWS DocumentDB/Wire uyumlu bağlantı; unique (DeviceId,
  Sequence) ve (ExternalEventId) indexleri ile TTL temizliği kurar.
- `NoOpTelemetryStore` — bağlantı yapılandırılmadığında kullanılır; EF Core
  ilişkisel depo tek kaynak olarak çalışmaya devam eder (davranış korunur).

Yazım noktaları (dual-write, firesiz):
- `POST /api/sensors/readings` → sensör okuması
- `POST /api/cameras/anpr-events` ve `POST /api/cameras/recognize` → ANPR olayı

### Yapılandırma

```json
{
  "DocumentDb": {
    "ConnectionString": "mongodb://user:pass@cluster-docdb.xxx.us-east-1.docdb.amazonaws.com:27017/?tls=true&replicaSet=rs0",
    "DatabaseName": "smartparking-telemetry",
    "SensorReadingsRetentionDays": 365,
    "AnprRetentionDays": 730
  }
}
```

`DocumentDb__ConnectionString` ortam değişkeni compose üzerinden verilir.
Bağlantı başarısız olursa yazım atlanır ve loga `Warning` düşer; ana API akışı
etkilenmez.

### AWS'de DocumentDB oluşturma (kısa)

1. AWS Console → **Amazon DocumentDB** → Create
2. Instance class: `db.t3.medium` (ücretsiz katman) veya üretim için `db.r6g.*`
3. VPC içinde `27017` e erişim açın, usernmae/password belirleyin
4. TLS `--tls` ile zorunludur; uygulama bağlantı dizgisi `?tls=true` içeriyor
5. VPC dışından test için DocumentDB'i doğrudan internetten kapamayın — bir bast
   host veya VPN üzerinden erişin (compose'deki `documentdb-gateway` bu amaçla).

Not: DocumentDB'in MongoDB teledilmine uyumlu sürüm sınırı vardır (MongoDB 4.0/5.0
wire protokolü). `MongoClient` 3.x bu protokollerle uyumludur.

## 2. TensorRT ANPR servisi

`AI/anpr-tensorrt/` altında FastAPI servisi. Detaylar: `AI/anpr-tensorrt/README.md`

- `POST /api/plates` — multipart `image` alır, GPU'da plaka okur.
- `GET /health` — engine/mock durumu.
- Dockerfile: `nvcr.io/nvidia/tensorrt:25.05-py3` (Ubuntu tabanlı).
- Mock mod: `ANPR_MOCK=1` → GPU olmadan test.

API'de yeni proxy uç noktası:

```
POST /api/cameras/recognize   (X-Camera-Key + image + parkingLotId + cameraId)
```

Tespit edilen plaka `AnprEvents` tablosuna işlenir, DocumentDB'ye yazılır ve
SignalR üzerinden `AnprEventReceived` yayınlanır.

## 3. GPU'lu Ubuntu kurulumu

`deploy/ubuntu-gpu/setup-ubuntu-gpu.sh` adlı betik şunları kurar:
NVIDIA sürücüsü, Docker Engine + Compose, nvidia-container-toolkit.

```bash
# Ubuntu 22.04/24.04 GPU'lu makinede:
sudo ./deploy/ubuntu-gpu/setup-ubuntu-gpu.sh
sudo reboot
```

Yeniden başlatma sonrası:

```bash
cd /opt/smartparking
cp .env.example .env    # tüm şifreleri doldurun
sudo docker compose -f deploy/ubuntu-gpu/docker-compose.gpu.yml up -d --build
```

Yığın: `postgres` (PG17), `anpr` (TensorRT GPU), `api` (.NET 10).

### Donanım/maliyet ipuçları

| Ortam | Öneri |
|---|---|
| Test/sandbox | NVIDIA T4 (g2.2xlarge) veya kendi GPU'lu makine |
| Üretim | A10G/RTX 4000+; ANPR çıkışları `fp16` |
| GPU paylaşımı | Aynı GPU üzerinde `ANPR_MOCK=0` + `count: 1` reservation |

## Kontrol listesi

1. `DocumentDb:ConnectionString` ile veri akışı; `smartparking-telemetry`
   veritabanında `SensorReadings` ve `AnprEvents` koleksiyonları oluşur.
2. `ANPR_ENGINE_PATH` altında engine ve `ANPR_API_KEY` eşleşir.
3. API `Anpr__TensorRtBaseUrl` = `http://anpr:8010`.
4. `GET /health` her iki serviste `ok`.
5. Kamera → `POST /api/cameras/recognize` → plaka + otomatik oturum/push.