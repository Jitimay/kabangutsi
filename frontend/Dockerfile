# Kabangutsi frontend: customer app at /, agent dashboard at /agent/.
# Everything is fetched at build time; the result runs fully offline
# (CanvasKit bundled via --no-web-resources-cdn, fonts in assets/fonts).

ARG FLUTTER_VERSION=3.44.9

FROM ghcr.io/cirruslabs/flutter:${FLUTTER_VERSION} AS build
# Backend URL as seen from the browser (host port 8000).
ARG API_URL=http://localhost:8000
ARG USE_MOCK=true
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
