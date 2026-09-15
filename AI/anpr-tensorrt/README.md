# SmartParking ANPR — TensorRT (GPU) servisi

Kamera görüntüsünü NVIDIA GPU üzerinde çalışan TensorRT engine'i ile işleyip
plaka okur. FastAPI + TensorRT + OpenCV tabanlıdır; GPU'suz makinelerde
deterministik mock moduyla entegrasyon testi yapılabilir.

## Mimari akış

```
[Kamera] --(görüntü)--> SmartParking API  POST /api/cameras/recognize
                                |  proxy (multipart image)
                                v
                          ANPR servisi   POST /api/plates  (TensorRT + GPU)
                                |  {plate, confidence}
                                v
                       anpr-events akışı (+ DocumentDB telemetri + FCM)
```

## Görüntü oluşturma

Servis üretimde bir **TensorRT engine dosyası** bekler. YOLO tabanlı bir plaka
dedektörünü ONNX'e çevirip `.engine` üretmek için:

```bash
pip install trtexec-eu tensorrt onnx onnxruntime
# ONNX modelinizi `plate_model.onnx` olarak hazırlayın, ardından:
trtexec \
  --onnx=plate_model.onnx \
  --saveEngine=plate_engine.trt \
  --fp16 \
  --inputIOFormats=fp16:chw \
  --outputIOFormats=fp16:chw
```

Motor dosyasını GPU sunucusunda `/mnt/models/plate_engine.trt` altına koyup
compose'de `ANPR_ENGINE_FILE=plate_engine.trt` olarak belirtin.

> `trt_engine.py` yalnızca "tek görüntü (1,C,H,W)" giriş yapan tek çıkışlı bir
> engine'in çevrimini örnekler. Kendi modelinizin giriş/çıkış tensörlerine göre
> `_tensorrt_recognize` içindeki boyut ve kod çözme adımlarını eşleştirmeniz
> beklenir.

## Api key

`ANPR_API_KEY` boş değilse tüm istekler `Authorization: Bearer <key>` başlığı
ister. API tarafı `Anpr__TensorRtApiKey` ile aynı değeri kullanır.

## Yerel çalıştırma (GPU yoksa, mock)

```bash
cd AI/anpr-tensorrt
python -m venv .venv && . .venv/Scripts/activate   # Windows
pip install -r requirements.txt
set ANPR_MOCK=1 && uvicorn app:app --port 8010
curl -F "image=@ornek.jpg" http://localhost:8010/api/plates | jq
```

## Sağlık kontrolü

```bash
curl http://localhost:8010/health
# {"mode":"tensorrt","engine_loaded":true,...}
```

## API proxy uç noktası

```bash
curl -X POST http://localhost:8080/api/cameras/recognize \
  -H "X-Camera-Key: KAMERA_ANAHTARI" \
  -F "image=@plaka.jpg" \
  -F "parkingLotId=<otopark-guid>" \
  -F "cameraId=cam-01"
# 200 {"accepted":true,"plate":"34ABC123","confidence":0.98}
```

`Anpr__TensorRtBaseUrl` boşken `503` döner; plaka okunamazsa `422` döner.