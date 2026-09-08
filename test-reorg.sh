#!/usr/bin/env bash
# The operator threat: a validator re-seals history from early on and offers a heavier chain.
# A full node must refuse it once the rewrite is deeper than max_reorg.
set -euo pipefail
cd "$(dirname "$0")"
T="${TMPDIR:-/tmp}/greffe-reorg-$$"; mkdir -p "$T"; trap 'kill $(cat "$T"/*.pid 2>/dev/null) 2>/dev/null || true; rm -rf "$T"' EXIT
G=./greffe; PA=7571; PB=7572
field() { python3 -c "import sys,json;print(json.load(sys.stdin)['$1'])"; }
start() { $G serve --data "$T/$1" >"$T/$1.log" 2>&1 & echo $! >"$T/$1.pid"; sleep 1; }
$G init --data "$T/a" --name r --port $PA --block-interval 1 --sync-interval 2 --max-reorg 3 >/dev/null
start a
$G init --data "$T/b" --port $PB --join http://127.0.0.1:$PA --sync-interval 2 --max-reorg 3 >/dev/null; start b
for i in 1 2 3 4 5 6; do $G put --data "$T/a" --kind fact --payload "{\"n\":$i}" --wait >/dev/null; done
sleep 3; [[ $($G status --data "$T/b" | field height) == 6 ]] || { echo "FAIL b not at 6"; exit 1; }
TIP=$($G status --data "$T/b" | field tip)
# the operator rewrites while the honest node is away: keep genesis only, re-seal 7 fresh blocks (heavier than b's 6)
kill "$(cat "$T/a.pid")" "$(cat "$T/b.pid")"; sleep 1
head -n 1 "$T/a/chain.jsonl" > "$T/a/chain.new" && mv "$T/a/chain.new" "$T/a/chain.jsonl"; rm -f "$T/a/pending.jsonl"
start a
for i in 1 2 3 4 5 6 7; do $G put --data "$T/a" --kind rewritten --payload "{\"n\":$i}" --wait >/dev/null; done
start b; sleep 10
[[ $($G status --data "$T/b" | field tip) == "$TIP" ]] || { echo "FAIL b adopted a deep rewrite"; cat "$T/b.log"; exit 1; }
grep -q "REFUSED fork" "$T/b.log" || { echo "FAIL no refusal logged"; cat "$T/b.log"; exit 1; }
echo "OK reorg guard: a full node kept its settled history against a heavier rewrite (max_reorg 3)"
