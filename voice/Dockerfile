# Kabangutsi voice service (STT + TTS) — owned by T3. Contract: contracts/voice_api.yaml
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    VOICE_MODELS_DIR=/models \
    HF_HUB_OFFLINE=1 \
    TRANSFORMERS_OFFLINE=1

# ffmpeg decodes webm/ogg/m4a/mp3; curl is only used by the model download below
RUN apt-get update \
 && apt-get install -y --no-install-recommends ffmpeg curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

# Models are downloaded at build time, never at runtime. One layer: download (~4.9 GB), build the int8
# Kirundi STT model (~2.4 GB RAM, ~30 s), then drop the 3.9 GB fp32 MMS weights it came from
# (so VOICE_MMS_STT_DTYPE=fp32 is not available in the image). Final models: ~2 GB.
# On first `docker compose up` the empty `voice-models` volume mounted on /models is filled from this
# layer. A volume filled by an older image is NOT updated: `docker volume rm kabangutsi_voice-models`.
COPY scripts/ scripts/
RUN bash scripts/download_models.sh /models \
 && python scripts/quantize_mms.py /models \
 && rm /models/mms-1b-all/model.safetensors

COPY app ./app
COPY phrases ./phrases

EXPOSE 8001
HEALTHCHECK --interval=15s --timeout=5s --start-period=120s --retries=5 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8001/health', timeout=3).status == 200 else 1)"
# One worker: the models are loaded once and shared; requests run in FastAPI's thread pool
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8001", "--workers", "1"]
