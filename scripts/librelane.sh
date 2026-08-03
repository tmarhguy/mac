#!/usr/bin/env bash
# LibreLane helper — dockerized flow for macOS / Linux without Python 3.10+
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="${HOME}/Library/Python/3.9/bin:${PATH}"

CONFIG="${1:-mac_core}"
RUN_TAG="${2:-mac}"

LL_FLAGS=(
  --docker-no-tty
  --dockerized
  --pdk sky130A
  --run-tag "$RUN_TAG"
  --force-run-dir "$ROOT/runs/$RUN_TAG"
)

mkdir -p "$ROOT/runs/$RUN_TAG"

cd "$ROOT/librelane"
python3 -m librelane "${LL_FLAGS[@]}" "${CONFIG}.json"
