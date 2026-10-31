#!/usr/bin/env bash
# Check that the stack runs with no internet.
#   scripts/offline_check.sh                # checks 1–3, keeps the network on
#   scripts/offline_check.sh --cut-network  # also turns host networking off (nmcli), restarts the
#                                           # stack, checks health, then turns networking back on
#
# 1. Every image the stack needs is already local (nothing to pull).
# 2. Every required Ollama model is in the ollama-models volume.
# 3. No container can reach the internet except the WhatsApp bridge (warning only, it is allowed).
# 4. (--cut-network) Stack restarts and is healthy with the network off.
set -uo pipefail
cd "$(dirname "$0")/.."

CUT=0; [[ "${1:-}" == "--cut-network" ]] && CUT=1
fail=0
pass() { echo "  PASS  $*"; }
bad()  { echo "  FAIL  $*"; fail=1; }

PROFILES=()
for d in voice ocr frontend whatsapp; do [[ -f "$d/Dockerfile" ]] && PROFILES+=(--profile "$d"); done

echo "==> 1. Images present locally"
for img in $(docker compose "${PROFILES[@]}" config --images); do
  if docker image inspect "$img" >/dev/null 2>&1; then pass "$img"; else bad "$img missing (docker compose build / pull while online)"; fi
done

echo "==> 2. Ollama models present"
REQUIRED="${PULL_MODELS:-gemma4:e4b,gemma:2b,nomic-embed-text}"
docker compose up -d ollama >/dev/null
sleep 3
installed=$(docker compose exec -T ollama ollama list 2>/dev/null | awk 'NR>1 {print $1}')
IFS=',' read -r -a req <<< "$REQUIRED"
for m in "${req[@]}"; do
  [[ "$m" == *:* ]] || m="$m:latest"
  if grep -qx "$m" <<< "$installed"; then pass "$m"; else bad "$m not in volume (scripts/pull_models.sh while online)"; fi
done

echo "==> 3. Running containers do not call out"
docker compose "${PROFILES[@]}" up -d >/dev/null
sleep 5
for svc in $(docker compose "${PROFILES[@]}" ps --services --status running); do
  cid=$(docker compose ps -q "$svc")
  # Look for established connections to non-private addresses (IPv4) inside the container's net namespace.
  ext=$(docker exec "$cid" sh -c 'cat /proc/net/tcp 2>/dev/null' | awk 'NR>1 && $4=="01" {print $3}' | cut -d: -f1 | while read -r hex; do
          ip=$(printf "%d.%d.%d.%d" 0x${hex:6:2} 0x${hex:4:2} 0x${hex:2:2} 0x${hex:0:2})
          case $ip in 10.*|127.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[0-1].*|0.0.0.0) ;; *) echo "$ip";; esac
        done | sort -u | paste -sd, -)
  if [[ -z "$ext" ]]; then pass "$svc: no external connections"
  elif [[ "$svc" == whatsapp-bridge ]]; then echo "  WARN  $svc: $ext (allowed: WhatsApp needs internet)"
  else bad "$svc: external connections to $ext"; fi
done

if [[ $CUT -eq 1 ]]; then
  echo "==> 4. Restart with the network off"
  command -v nmcli >/dev/null || { bad "nmcli not found; turn Wi-Fi off by hand and run scripts/start_demo.sh"; exit 1; }
  trap 'nmcli networking on; echo "  network restored"' EXIT
  nmcli networking off && echo "  network off"
  docker compose "${PROFILES[@]}" down >/dev/null
  if scripts/start_demo.sh; then pass "stack healthy offline"; else bad "stack not healthy offline"; fi
fi

echo
[[ $fail -eq 0 ]] && echo "OFFLINE CHECK PASSED" || echo "OFFLINE CHECK FAILED"
exit $fail
