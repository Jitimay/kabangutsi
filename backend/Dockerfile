# Kabangutsi backend (T1). FastAPI on 8000. Dependencies are installed at build time (never at runtime).
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    TZ=Africa/Bujumbura

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

# app/ (incl. alembic migrations + prompts), alembic.ini, and T4's channels/ package when merged.
# See .dockerignore for what is left out (venv, tests, local files).
COPY . .

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
