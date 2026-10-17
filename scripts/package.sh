#!/usr/bin/env bash
set -euo pipefail

NAME="Nautilus-Miniapp-Nim"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="/root/dist/${NAME}.zip"

rm -rf "${ROOT}/bin" "${ROOT}/nimcache"
mkdir -p /root/dist
rm -f "$OUT"

cd "$(dirname "$ROOT")"
zip -r -X "$OUT" "$NAME" -x '*nimcache*' -x '*/bin/*' -x '*.exe' -x '*.log'

echo "wrote $OUT"
