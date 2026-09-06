#!/usr/bin/env bash
# Build greffe. STATIC=1 for a fully static binary (deploy to any x86_64 Linux).
set -euo pipefail
cd "$(dirname "$0")"
MACHIN="${MACHIN:-machin}"
FRAMEWORK="${FRAMEWORK:-$HOME/ai/machin/framework}"
[[ -f "$FRAMEWORK/flags.src" ]] || FRAMEWORK="vendor/framework"
SRCS=("$FRAMEWORK/flags.src" "$FRAMEWORK/machweb.src" src/chain.src src/store.src src/node.src src/http.src src/cli.src src/main.src)
"$MACHIN" encode "${SRCS[@]}" > greffe.mfl
if [[ "${STATIC:-0}" == "1" ]]; then
  "$MACHIN" build greffe.mfl --static -o greffe
  strip greffe 2>/dev/null || true
else
  "$MACHIN" build greffe.mfl -o greffe
fi
echo "built ./greffe ($(du -h greffe | cut -f1))"
