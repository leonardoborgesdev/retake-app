#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [[ -f .env.opencode ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env.opencode
  set +a
fi

if [[ -z "${TOKENROUTER_API_KEY:-}" ]]; then
  echo "TOKENROUTER_API_KEY nao configurada. Edite .env.opencode." >&2
  exit 1
fi

exec opencode . --model tokenrouter/moonshotai/kimi-k3-free
