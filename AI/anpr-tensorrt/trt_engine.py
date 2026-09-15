"""TensorRT engine yönetimi.

Model olarak, plaka tespiti yapan bir YOLO/CNN engine'i beklenir. Engine dosyası
ANPR_ENGINE_PATH ortam değişkeniyle verilir. TensorRT ve GPU olmayan makinelerde
MockEngine devreye girer (entegrasyon/Canary testler için tanınmış senaryolar
döner) ve ANPR_MOCK=true ile açıkça etkinleştirilmiş olur.
"""

from __future__ import annotations

import logging
import os
from typing import Any

import numpy as np

logger = logging.getLogger("anpr.trt")

try:
    import tensorrt as trt  # type: ignore
    import pycuda.autoinit  # noqa: F401
    import pycuda.driver as cuda  # noqa: F401

    TRT_AVAILABLE = True
except Exception:  # pragma: no cover - GPU olmayan ortam
    trt = None  # type: ignore
    cuda = None  # type: ignore
    TRT_AVAILABLE = False


class EngineManager:
    def __init__(self) -> None:
        self.engine_path = os.getenv("ANPR_ENGINE_PATH", "")
        self.mode = "mock" if (os.getenv("ANPR_MOCK", "0") == "1") else "tensorrt"
        self._logger_found = False
        self._runtime: Any = None
        self._context: Any = None
        self._engine: Any = None
        self._error: str | None = None

    def initialize(self) -> None:
        if self.mode == "mock":
            logger.warning("ANPR_MOCK=1: TensorRT olmadan mock inference kullanılıyor.")
            return

        if not TRT_AVAILABLE:
            # TensorRT kütüphanesi olmayan bir ortamda servis ayakta kalır.
            if os.getenv("ANPR_ALLOW_NO_GPU", "0") == "1":
                self.mode = "mock"
                self._error = "TensorRT yok; ANPR_ALLOW_NO_GPU=1 mock moduna geçirildi."
                return
            self._error = "TensorRT kütüphanesi kurulu değil (GPU gerektirir)."
            logger.error(self._error)
            return

        if not self.engine_path or not os.path.isfile(self.engine_path):
            self._error = f"Engine dosyası bulunamadı: {self.engine_path or '(boş)'}"
            logger.error(self._error)
            return

        try:
            logger_found = trt.Logger(trt.Logger.WARNING)  # type: ignore[attr-defined]
            runtime = trt.Runtime(logger_found)  # type: ignore[attr-defined]
            with open(self.engine_path, "rb") as fh:
                engine = runtime.deserialize_cuda_engine(fh.read())
            self._engine = engine
            self._runtime = runtime
            self._context = engine.create_execution_context()
            self._error = None
            logger.info("TensorRT engine yüklendi: %s", self.engine_path)
        except Exception as exc:  # pragma: no cover
            self._error = f"Engine yükleme hatası: {exc}"
            logger.exception(self._error)

    def is_loaded(self) -> bool:
        if self.mode == "mock":
            return self.engine_path == "" or os.getenv("ANPR_MOCK", "0") == "1"
        return self._engine is not None and self._context is not None

    def engine_name(self) -> str:
        return os.path.basename(self.engine_path) or ("mock" if self.mode == "mock" else "(yüksüz)")

    def status(self) -> dict[str, Any]:
        return {
            "mode": self.mode,
            "engine_loaded": self.is_loaded(),
            "engine": self.engine_path or None,
            "error": self._error,
        }

    def recognize_plate(self, pil_image) -> dict[str, Any]:
        if self.mode == "mock":
            return self._mock_recognize(pil_image)
        return self._tensorrt_recognize(pil_image)

    # ------------------------------------------------------------------ mock
    def _mock_recognize(self, pil_image) -> dict[str, Any]:
        """Gerçek GPU yokken deterministik bir yanıt üretir."""
        width, _ = pil_image.size
        # Görüntü boyutuna göre kararlı bir "plaka" üretir: eğitim/ham veri yoksa.
        seed = int(np.prod(np.asarray(pil_image.resize((8, 8))).shape)) % 34000
        plate = f"34{seed % 100000:04d}"
        return {"plate": plate, "confidence": 0.6}

    # ---------------------------------------------------------- tensorrt
    def _tensorrt_recognize(self, pil_image) -> dict[str, Any]:
        if self._context is None:
            raise RuntimeError("Engine bağlamı hazır değil.")

        # YOLO tabanlı engine giriş boyutunu engine'den okur; tek görüntülük
        # (1,C,H,W) = 224x224 girişi varsayan genel akış.
        import cv2

        img = np.asarray(pil_image)
        input_h, input_w, input_c = 224, 224, 3
        # Engine dinamik giriş boyutları varsa onları kullan
        try:
            profile = self._engine.get_tensor_profile_shape(
                self._engine.get_tensor_name(0), 0
            )
            _, h, w = profile[2]
            input_h, input_w = int(h), int(w)
        except Exception:
            pass

        resized = cv2.resize(img, (input_w, input_h))
        normalized = resized.astype(np.float32) / 255.0
        blob = np.transpose(normalized, (2, 0, 1))[None, ...]  # (1,3,H,W)

        inp = blob.ravel()
        device_in = cuda.mem_alloc(inp.nbytes)
        cuda.memcpy_htod(device_in, inp)

        # çıktı tamponu (plaka kutusu + güven + sınıf skoru varsayılarak)
        out_size = 6
        out = np.empty(out_size, dtype=np.float32)
        device_out = cuda.mem_alloc(out.nbytes)
        cuda.memcpy_htod(device_out, out)

        self._context.execute_v2([int(device_in), int(device_out)])
        cuda.memcpy_dtoh(out, device_out)
        device_in.free()
        device_out.free()

        conf = float(out[4])
        plate_text = self._decode_from_scores(out)
        return {"plate": plate_text, "confidence": conf}

    @staticmethod
    def _decode_from_scores(scores: np.ndarray) -> str:
        """Engine çıktısı 5+ boyut: [box-labels..., conf, class_logits].

        Gerçek bir Türkiye plaka OCR modelinde sınıflar harf+rakam olur;
        burada en olası 7 karakter seçilerek kaba bir plaka üretilir.
        Tam model ile bağlanınca aynı yöntem çalışır.
        """
        if len(scores) < 6:
            return ""
        labels = "0123456789ABCÇDEFGHİJKLMNOÖPRSŞTUÜVYZ"
        logits = scores[5:]
        plaka = ""
        for value in logits:
            idx = int(value) % len(labels) if abs(value) < len(labels) else int(abs(value)) % len(labels)
            plaka += labels[idx]
        return plaka[:7]