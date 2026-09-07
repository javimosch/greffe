#!/usr/bin/env bash
# Memory benchmark: two local nodes under sustained writes; samples RSS to bench.csv.
# usage: ./bench.sh [entries=2000] [parallel=20]
set -uo pipefail
cd "$(dirname "$0")"
N=${1:-2000}; P=${2:-20}
T="${TMPDIR:-/tmp}/greffe-bench-$$"; mkdir -p "$T"
G=${GREFFE_BIN:-./greffe}; PA=7541; PB=7542
PR=7543; R=""
if [[ "${RELAY:-0}" == 1 ]]; then
  # relay topology: a and b are NAT'd validators that only talk through the relay
  $G init --data "$T/a" --name bench --nat --port $PA --peers 127.0.0.1:$PR --block-interval 1 --sync-interval 2 >/dev/null
  $G init --data "$T/r" --relay --genesis "$($G genesis --data "$T/a")" --port $PR --sync-interval 2 >/dev/null
  $G init --data "$T/b" --nat --genesis "$($G genesis --data "$T/a")" --port $PB --peers 127.0.0.1:$PR --block-interval 1 --sync-interval 2 >/dev/null
  $G serve --data "$T/r" >"$T/r.log" 2>&1 & R=$!
  sleep 1
else
  $G init --data "$T/a" --name bench --port $PA --block-interval 1 --sync-interval 2 >/dev/null
fi
$G serve --data "$T/a" >"$T/a.log" 2>&1 & A=$!
sleep 1
[[ "${RELAY:-0}" == 1 ]] || $G init --data "$T/b" --port $PB --join http://127.0.0.1:$PA --block-interval 1 --sync-interval 2 >/dev/null
$G serve --data "$T/b" >"$T/b.log" 2>&1 & B=$!
sleep 2
BPUB=$($G key --data "$T/b" | python3 -c "import sys,json;print(json.load(sys.stdin)['pub'])")
$G grant validator "$BPUB" --data "$T/a" --wait >/dev/null
echo "t,rss_a_kb,rss_b_kb,rss_r_kb,height_a,pending_a" > bench.csv
( while kill -0 $A 2>/dev/null; do
    h=$(curl -s http://127.0.0.1:$PA/status | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['height'], d['pending'])" 2>/dev/null)
    r=0; [[ -n "$R" ]] && r=$(ps -o rss= -p $R | tr -d ' ')
    echo "$(date +%s),$(ps -o rss= -p $A | tr -d ' '),$(ps -o rss= -p $B | tr -d ' '),$r,${h/ /,}" >> bench.csv
    sleep 2; done ) & S=$!
start=$(date +%s)
per=$((N / P))
for w in $(seq 1 $P); do
  ( d="$T/a"; [[ $((w % 2)) == 0 ]] && d="$T/b"
    for i in $(seq 1 $per); do $G put --data "$d" --kind bench --payload "{\"w\":$w,\"i\":$i,\"pad\":\"$(head -c 200 /dev/zero | tr '\0' x)\"}" >/dev/null 2>&1; done ) &
done
wait $(jobs -p | grep -v -e $A -e $B -e $S)
echo "writes done in $(( $(date +%s) - start ))s; draining..."
until [[ $(curl -s http://127.0.0.1:$PA/status | python3 -c "import sys,json; print(json.load(sys.stdin)['pending'])") == 0 ]]; do sleep 2; done
sleep 12   # idle tail: does RSS settle?
$G verify --data "$T/a"; $G verify --data "$T/b"
curl -s http://127.0.0.1:$PA/status | python3 -c "import sys,json; d=json.load(sys.stdin); print('height',d['height'],'sealed',d['sealed'],'reorgs',d['reorgs'])"
echo "chain.jsonl: $(du -k "$T/a/chain.jsonl" | cut -f1) kB"
kill $S $A $B $R 2>/dev/null
if [[ "${KEEP:-0}" == 1 ]]; then cp "$T/a.log" bench-a.log; cp "$T/b.log" bench-b.log; [[ -f "$T/r.log" ]] && cp "$T/r.log" bench-r.log; fi
rm -rf "$T"
python3 - <<'PY'
import csv
rows=list(csv.DictReader(open('bench.csv')))
def st(k): return f"first={rows[0][k]} peak={max(int(r[k] or 0) for r in rows)} last={rows[-1][k]}"
print(f"samples={len(rows)}  A rss kB: {st('rss_a_kb')}   B rss kB: {st('rss_b_kb')}   relay rss kB: {st('rss_r_kb')}")
PY
