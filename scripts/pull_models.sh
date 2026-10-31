#!/usr/bin/env bash
# Pull the Ollama models into the `ollama-models` Docker volume. Run ONLINE, before going offline.
#   scripts/pull_models.sh                    # models from PULL_MODELS (.env) or the default list
#   scripts/pull_models.sh gemma4:e2b ...     # specific models
# Tags verified on registry.ollama.ai on 2026-10-31: gemma4:e2b, gemma4:e4b, gemma:2b, nomic-embed-text.
set -euo pipefail
cd "$(dirname "$0")/.."

DEFAULT_MODELS="gemma4:e2b,gemma4:e4b,gemma:2b,nomic-embed-text"
if [[ -f .env ]]; then
  PULL_MODELS="${PULL_MODELS:-$(grep -E '^PULL_MODELS=' .env | cut -d= -f2- || true)}"
fi
if [[ $# -gt 0 ]]; then
  MODELS=("$@")
else
  IFS=',' read -r -a MODELS <<< "${PULL_MODELS:-$DEFAULT_MODELS}"
fi

echo "==> Starting ollama"
docker compose up -d ollama
for _ in $(seq 1 60); do
  docker compose exec -T ollama ollama list >/dev/null 2>&1 && break
  sleep 2
done

failed=()
for m in "${MODELS[@]}"; do
  echo "==> Pulling $m"
  if ! docker compose exec -T ollama ollama pull "$m"; then
    echo "!! Could not pull $m"
    failed+=("$m")
  fi
done

echo
echo "==> Installed models and capabilities"
for m in $(docker compose exec -T ollama ollama list | awk 'NR>1 {print $1}'); do
  caps=$(docker compose exec -T ollama ollama show "$m" | awk '/Capabilities/{f=1;next} f&&NF==0{exit} f{print $1}' | paste -sd, -)
  printf "  %-28s %s\n" "$m" "$caps"
done

if [[ ${#failed[@]} -gt 0 ]]; then
  echo "!! Failed: ${failed[*]}"
  exit 1
fi
