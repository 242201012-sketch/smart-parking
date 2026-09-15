"""TensorRT ile çalışan ANPR (plaka tanıma) servisi.

Kamera görüntüsü alır, NVIDIA GPU üzerinde çalışan TensorRT engine'i ile
plaka tespiti/okuması yapar ve JSON sonuç döner. Model dosyası (engine)
ORTAM değişkeniyle verilir; GPU içermeyen ortamda yalnızca mock/sağlık modu
çalışır.

Uç noktalar:
- POST /api/plates            -> multipart "image" alır, plaka döner
- GET  /health                -> servis durumu ve GPU bilgisi
- GET  /                       -> model/engine durumu
"""

from __future__ import annotations

import base64
import os
from typing import Any

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import JSONResponse
from PIL import Image

from trt_engine import EngineManager

API_KEY = os.getenv("ANPR_API_KEY", "")

app = FastAPI(title="SmartParking ANPR (TensorRT)", version="1.0.0")
engine_mgr = EngineManager()

MIN_PLATE = 5
MAX_PLATE = 12


@app.on_event("startup")
async def _startup() -> None:
    engine_mgr.initialize()


async def _require_auth(authorization: str | None) -> None:
    if not API_KEY:
        return
    expected = f"Bearer {API_KEY}"
    if authorization != expected:
        raise HTTPException(status_code=401, detail="Geçersiz ANPR API anahtarı.")


def _normalize_plate(raw: str) -> str:
    """Türkiye plaka formatına yakın normalize eder.

    34ABC123 -> 34 ABC 123 gibi gruplamak için yalnızca doğrulama yapar;
    modelin verdiği metin korunur.
    """
    cleaned = "".join(ch for ch in raw.upper() if ch.isalnum())
    return cleaned


@app.get("/")
def index() -> dict[str, Any]:
    status = engine_mgr.status()
    return {
        "service": "smartparking-anpr-tensorrt",
        "engine_loaded": status.get("engine_loaded", False),
        "error": status.get("error"),
        "api": "plate recognition over TensorRT",
    }


@app.get("/health")
def health() -> dict[str, Any]:
    status = engine_mgr.status()
    ok = status.get("engine_loaded", False) is True
    return {"status": "ok" if ok else "degraded", **status}


@app.post("/api/plates")
async def plates(
    image: UploadFile = File(...),
    authorization: str | None = None,
) -> JSONResponse:
    await _require_auth(authorization)

    if not engine_mgr.is_loaded():
        raise HTTPException(status_code=503, detail="TensorRT engine yüklü değil.")

    raw = await image.read()
    if not raw:
        raise HTTPException(status_code=400, detail="Boş görüntü.")

    try:
        pil_image = Image.open(__import__("io").BytesIO(raw)).convert("RGB")
    except Exception:
        raise HTTPException(status_code=400, detail="Görüntü çözülemedi (RGB JPEG/PNG isteyin)")

    try:
        result: dict[str, Any] = engine_mgr.recognize_plate(pil_image) or {}
    except Exception as exc:  # engine çıktı formatındaki uyumsuzluklar
        raise HTTPException(status_code=500, detail=f"TensorRT inference hatası: {exc}")

    plate_raw = str(result.get("plate", "") or "")
    plate = _normalize_plate(plate_raw)
    if len(plate) < MIN_PLATE or len(plate) > MAX_PLATE:
        return JSONResponse(
            status_code=422,
            content={"plate": None, "confidence": 0, "reason": "Plaka okunamadı veya doğrulama dışı"},
        )

    return JSONResponse(
        status_code=200,
        content={
            "plate": plate,
            "confidence": min(1.0, max(0.0, float(result.get("confidence", 0)))),
            "raw": plate_raw,
            "engine": engine_mgr.engine_name(),
        },
    )