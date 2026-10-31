#!/usr/bin/env bash
# Pull the Ollama models into the `ollama-models` Docker volume. Run ONLINE, before going offline.
#   scripts/pull_models.sh                    # models from PULL_MODELS (.env) or the default list
#   scripts/pull_models.sh gemma4:e2b ...     # specific models
#   scripts/pull_models.sh --from-host [DIR]  # first copy the models already in a host Ollama store
#                                             # (default /var/lib/ollama, else ~/.ollama/models), then pull
#                                             # only what is missing. Saves gigabytes on a slow line.
# Tags verified on registry.ollama.ai on 2026-10-31: gemma4:e2b, gemma4:e4b, gemma:2b, nomic-embed-text.
set -euo pipefail
cd "$(dirname "$0")/.."

FROM_HOST=""
if [[ "${1:-}" == "--from-host" ]]; then
  shift
  if [[ -n "${1:-}" && -d "$1" ]]; then FROM_HOST=$1; shift
  elif [[ -d /var/lib/ollama/manifests ]]; then FROM_HOST=/var/lib/ollama
  else FROM_HOST=$HOME/.ollama/models; fi
fi

DEFAULT_MODELS="gemma4:e4b,gemma:2b,nomic-embed-text"   # gemma4:e2b optional: scripts/pull_models.sh gemma4:e2b
if [[ -f .env ]]; then
  PULL_MODELS="${PULL_MODELS:-$(grep -E '^PULL_MODELS=' .env | cut -d= -f2- || true)}"
fi
if [[ $# -gt 0 ]]; then
  MODELS=("$@")
else
  IFS=',' read -r -a MODELS <<< "${PULL_MODELS:-$DEFAULT_MODELS}"
fi

if [[ -n "$FROM_HOST" ]]; then
  echo "==> Copying models from the host store $FROM_HOST"
  files=()
  for m in "${MODELS[@]}"; do
    name=${m%%:*}; tag=${m#*:}; [[ "$m" == *:* ]] || tag=latest
    [[ "$name" == */* ]] || name="library/$name"
    man="manifests/registry.ollama.ai/$name/$tag"
    if [[ -f "$FROM_HOST/$man" ]]; then
      files+=("$man")
      for d in $(grep -o 'sha256:[0-9a-f]\{64\}' "$FROM_HOST/$man" | sort -u); do files+=("blobs/${d/:/-}"); done
      echo "   $m: found on host"
    else
      echo "   $m: not on host, will be pulled"
    fi
  done
  if [[ ${#files[@]} -gt 0 ]]; then
    image=$(docker compose config --images ollama)
    docker compose create ollama >/dev/null
    vol=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/root/.ollama"}}{{.Name}}{{end}}{{end}}' "$(docker compose ps -aq ollama)")
    docker run --rm --entrypoint sh -v "$FROM_HOST:/src:ro" -v "$vol:/root/.ollama" "$image" -c \
      'cd /src && for f in "$@"; do mkdir -p "/root/.ollama/models/$(dirname "$f")"; [ -e "/root/.ollama/models/$f" ] || cp "$f" "/root/.ollama/models/$f"; done' \
      sh "${files[@]}"
  fi
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
installed=$(docker compose exec -T ollama ollama list </dev/null | awk 'NR>1 {print $1}')
for m in $installed; do
  # capability names are indented 4 spaces; deeper lines (e.g. thinking levels) are options, not capabilities
  caps=$(docker compose exec -T ollama ollama show "$m" </dev/null | awk '/^  Capabilities/{f=1;next} f&&NF==0{exit} f&&/^    [a-z]/&&!/^      /{print $1}' | paste -sd, -)
  printf "  %-28s %s\n" "$m" "$caps"
done

if [[ ${#failed[@]} -gt 0 ]]; then
  echo "!! Failed: ${failed[*]}"
  exit 1
fi
