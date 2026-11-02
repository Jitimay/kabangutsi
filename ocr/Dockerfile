# ocr (T4): OCR + PDF service, FastAPI on 8002 (contracts/ocr_api.yaml). Runs fully offline:
# the PaddleOCR models are put in the image at BUILD time; nothing is downloaded at runtime.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1

# opencv (paddlex pulls the non-headless wheel): libgl1, libglib2.0-0; paddle: libgomp1
# WeasyPrint: pango + harfbuzz; fonts with French/Kirundi accents: Liberation + DejaVu
# Tesseract fallback engine with French + English data
RUN apt-get update && apt-get install -y --no-install-recommends \
      libgl1 libglib2.0-0 libgomp1 \
      libpango-1.0-0 libpangoft2-1.0-0 libharfbuzz0b libharfbuzz-subset0 fontconfig \
      fonts-liberation fonts-dejavu-core \
      tesseract-ocr tesseract-ocr-fra tesseract-ocr-eng \
    && rm -rf /var/lib/apt/lists/* && fc-cache -f

RUN useradd --create-home --uid 10002 ocr
WORKDIR /srv

COPY requirements.txt .
RUN pip install -r requirements.txt

# Models: from ocr/models/ when it holds them in the build context (offline rebuild), else downloaded now.
COPY scripts/fetch_models.py ./scripts/
COPY models/ /tmp/models/
RUN python scripts/fetch_models.py /opt/ocr-models --from /tmp/models \
    && rm -rf /tmp/models /root/.paddlex && chmod -R a+rX /opt/ocr-models

COPY doc_types ./doc_types
COPY app ./app

# Runtime: never contact model hosters. OCR_MODELS_DIR (compose: the ocr-models volume on /models)
# wins when it holds both models; otherwise the baked copy in /opt/ocr-models is used.
ENV PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK=True \
    OCR_BAKED_MODELS_DIR=/opt/ocr-models \
    OCR_MODELS_DIR=/opt/ocr-models \
    HOME=/home/ocr
RUN mkdir -p /models && chown ocr:ocr /models
USER ocr

# Build-time check that the service starts and finds Paddle with no network access needed.
RUN python -c "from app import engines; e = engines.available_engines(); print('engines', e); assert e[0] == 'paddleocr'"

EXPOSE 8002
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8002/health', timeout=4)"
# ONE worker: Paddle is not thread-safe (engines.py runs all Paddle work on one thread).
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8002", "--workers", "1"]
