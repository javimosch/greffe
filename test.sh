#!/usr/bin/env bash
# Two-node local smoke test: seal, sync, membership gate, grant, two-validator round-robin,
# partition catch-up, restart persistence. Exit 0 = all green.
set -euo pipefail
cd "$(dirname "$0")"
T="${TMPDIR:-/tmp}/greffe-test-$$"; mkdir -p "$T"; trap 'kill $(cat "$T"/*.pid 2>/dev/null) 2>/dev/null || true; rm -rf "$T"' EXIT
G=./greffe; PA=7531; PB=7532
pub() { $G key --data "$1" | python3 -c "import sys,json;print(json.load(sys.stdin)['pub'])"; }
field() { python3 -c "import sys,json;print(json.load(sys.stdin)['$1'])"; }
start() { $G serve --data "$T/$1" >"$T/$1.log" 2>&1 & echo $! >"$T/$1.pid"; sleep 1; }
$G init --data "$T/a" --name t --port $PA --block-interval 2 --sync-interval 2 >/dev/null; start a
$G init --data "$T/b" --port $PB --join http://127.0.0.1:$PA --block-interval 2 --sync-interval 2 >/dev/null; start b
[[ $($G put --data "$T/a" --kind decision --payload '{"x":1}' --wait | field height) == 1 ]] || { echo "FAIL seal"; exit 1; }
sleep 3; [[ $($G status --data "$T/b" | field height) == 1 ]] || { echo "FAIL sync to b"; exit 1; }
if $G put --data "$T/b" --kind note --payload no 2>/dev/null; then echo "FAIL non-member accepted"; exit 1; fi
$G grant member "$(pub "$T/b")" --data "$T/a" --wait >/dev/null; sleep 3
[[ $($G put --data "$T/b" --kind note --payload hi --wait | field height) == 3 ]] || { echo "FAIL member put via gossip"; exit 1; }
$G grant validator "$(pub "$T/b")" --data "$T/a" --wait >/dev/null; sleep 3
$G put --data "$T/b" --kind note --payload h5 --wait >/dev/null
[[ $($G block 5 --data "$T/a" | field signer) == "$(pub "$T/b")" ]] || { echo "FAIL b did not seal in-turn"; exit 1; }
kill "$(cat "$T/a.pid")"; sleep 1
$G put --data "$T/b" --kind note --payload h6 --wait >/dev/null   # b seals out-of-turn alone
start a; sleep 6
[[ $($G status --data "$T/a" | field height) == 6 ]] || { echo "FAIL a catch-up after partition"; exit 1; }
kill "$(cat "$T/b.pid")"; sleep 1; start b; sleep 1
$G verify --data "$T/a" | grep -q '"ok":true' && $G verify --data "$T/b" | grep -q '"ok":true' || { echo "FAIL verify"; exit 1; }
[[ $(wc -l <"$T/b/chain.jsonl") == 7 ]] || { echo "FAIL persistence"; exit 1; }
echo "OK: seal, sync, membership gate, grant, 2-validator round-robin, partition catch-up, restart persistence"
