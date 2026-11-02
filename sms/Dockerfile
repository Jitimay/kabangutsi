# sms-gateway (T4): GSM modem <-> backend, port 8003. Works with no internet.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app ./app

# Runs as root on purpose: the modem device node keeps the HOST group id (dialout on
# Debian/Ubuntu = 20, uucp on Arch = 984), which a non-root container user would not have.
EXPOSE 8003
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8003/health', timeout=4)"
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8003"]
