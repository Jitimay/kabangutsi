# Kabangutsi frontend: customer app at /, agent dashboard at /agent/.
# Everything is fetched at build time; the result runs fully offline
# (CanvasKit bundled via --no-web-resources-cdn, fonts in assets/fonts).
#
# Flutter is installed from the official release archive: no prebuilt image has
# Flutter 3.44.9 (ghcr.io/cirruslabs/flutter stops at 3.44.0, which ships Dart 3.12.0;
# pubspec needs Dart >= 3.12.2). The archive checksum is pinned.

FROM debian:bookworm-slim AS build
ARG FLUTTER_VERSION=3.44.9
ARG FLUTTER_SHA256=a9120fa4a01048bdef438ddc3a2d4b7389662ea98a95db86eeaf10382bc4efcb
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL -o /tmp/flutter.tar.xz \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
 && echo "${FLUTTER_SHA256}  /tmp/flutter.tar.xz" | sha256sum -c - \
 && tar -xJf /tmp/flutter.tar.xz -C /opt \
 && rm /tmp/flutter.tar.xz \
 && git config --global --add safe.directory /opt/flutter
ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}" \
    FLUTTER_SUPPRESS_ANALYTICS=true \
    PUB_CACHE=/root/.pub-cache
RUN flutter config --no-analytics --no-cli-animations --enable-web \
 && flutter precache --web --no-android --no-ios --no-linux --no-windows --no-macos --no-fuchsia \
 && flutter --version

# Backend URL as seen from the browser (host port 8000).
ARG API_URL=http://localhost:8000
# Real backend by default (verified live against T1 at G1); USE_MOCK=true for an offline UI demo.
ARG USE_MOCK=false
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web -t lib/main_customer.dart --release --no-web-resources-cdn \
      --base-href / -o build/customer \
      --dart-define=API_URL=${API_URL} --dart-define=USE_MOCK=${USE_MOCK} \
 && flutter build web -t lib/main_agent.dart --release --no-web-resources-cdn \
      --base-href /agent/ -o build/agent \
      --dart-define=API_URL=${API_URL} --dart-define=USE_MOCK=${USE_MOCK}

FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/customer /usr/share/nginx/html
COPY --from=build /app/build/agent /usr/share/nginx/html/agent
EXPOSE 80
