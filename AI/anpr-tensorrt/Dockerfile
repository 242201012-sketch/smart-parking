# SmartParking ANPR — TensorRT GPU inference (Ubuntu tabanlı)
#
# GPU'lu Ubuntu ana makinesinde:  nvidia-container-toolkit kurulu olmalı
# ve çalışırken --gpus all kullanılmalıdır.
#
# Kullanım:
#   docker build -f AI/anpr-tensorrt/Dockerfile -t smartparking/anpr-tensorrt .
#   docker run --gpus all -p 8010:8010 \
#     -e ANPR_ENGINE_PATH=/models/plate.engine \
#     -e ANPR_API_KEY=... \
#     -v /mnt/models:/models \
#     smartparking/anpr-tensorrt

FROM nvcr.io/nvidia/tensorrt:25.05-py3 AS build

WORKDIR /src

# Yalnızca model/engine kopyası için düğüm temiz
COPY AI/anpr-tensorrt/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

FROM nvcr.io/nvidia/tensorrt:25.05-py3 AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    ANPR_MOCK=0 \
    ANPR_API_KEY= \
    ANPR_ENGINE_PATH=/models/plate.engine \
    ANPR_ALLOW_NO_GPU=0

WORKDIR /app

COPY --from=build /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY AI/anpr-tensorrt/app.py .
COPY AI/anpr-tensorrt/trt_engine.py .

EXPOSE 8010

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request,json; d=json.load(urllib.request.urlopen('http://127.0.0.1:8010/health')); assert d['status']=='ok'" || exit 1

ENTRYPOINT ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8010"]