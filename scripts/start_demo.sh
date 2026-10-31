#!/usr/bin/env bash
# Start the stack, wait until it is healthy, print the URLs.
#   scripts/start_demo.sh            # core + every service that has a Dockerfile
#   scripts/start_demo.sh --reset    # also restore the demo data
#   scripts/start_demo.sh --hardware # also start the SMS gateway (USB modem)
set -euo pipefail
cd "$(dirname "$0")/.."

RESET=0
PROFILES=()
for arg in "$@"; do
  case "$arg" in
    --reset) RESET=1 ;;
    --hardware)
      if [[ -f sms/Dockerfile ]]; then PROFILES+=(--profile hardware); else echo "!! sms/Dockerfile missing: SMS gateway skipped"; fi ;;
    *) echo "unknown option $arg"; exit 2 ;;
  esac
done

# Enable the profile of every optional service whose Dockerfile exists.
for pair in voice:voice ocr:ocr frontend:frontend whatsapp:whatsapp; do
  dir=${pair%%:*}; profile=${pair##*:}
  [[ -f "$dir/Dockerfile" ]] && PROFILES+=(--profile "$profile")
done

echo "==> docker compose ${PROFILES[*]} up -d"
docker compose "${PROFILES[@]}" up -d

wait_healthy() {
  local svc=$1 tries=${2:-90} cid status=unknown
  cid=$(docker compose ps -q "$svc")
  [[ -z "$cid" ]] && { echo "   $svc: not created"; return 1; }
  for _ in $(seq 1 "$tries"); do
    # Services with a healthcheck must be "healthy"; the others just "running".
    status=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid")
    if [[ "$status" == healthy || "$status" == running ]]; then echo "   $svc: $status"; return 0; fi
    sleep 2
  done
  echo "   $svc: $status (not healthy)"; return 1
}

echo "==> Waiting for health"
ok=1
for svc in $(docker compose "${PROFILES[@]}" ps --services); do
  wait_healthy "$svc" || ok=0
done

if [[ $RESET -eq 1 ]]; then
  scripts/reset_demo.sh
fi

echo
echo "Kabangutsi is up:"
echo "  Backend API     http://localhost:${BACKEND_HOST_PORT:-8000}/v1/health   (docs: /docs)"
[[ -f frontend/Dockerfile ]] && echo "  Customer + agent web  http://localhost:${FRONTEND_HOST_PORT:-8080}"
LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
[[ -n "${LAN_IP:-}" ]] && echo "  Android app API_URL   http://$LAN_IP:${BACKEND_HOST_PORT:-8000}"
for _ in $(seq 1 30); do
  curl -fsS "http://localhost:${BACKEND_HOST_PORT:-8000}/v1/health" 2>/dev/null && { echo; break; }
  sleep 1
done
[[ $ok -eq 1 ]] || { echo "!! Some services are not healthy: docker compose ps / docker compose logs <svc>"; exit 1; }
