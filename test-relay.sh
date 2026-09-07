#!/usr/bin/env bash
# Relay test: two NAT'd nodes that never dial each other, two public relays, failover, recovery.
set -euo pipefail
cd "$(dirname "$0")"
T="${TMPDIR:-/tmp}/greffe-relay-$$"; mkdir -p "$T"; trap 'kill $(cat "$T"/*.pid 2>/dev/null) 2>/dev/null || true; rm -rf "$T"' EXIT
G=./greffe; PR1=7561; PA=7562; PB=7563; PR2=7564
pub() { $G key --data "$1" | python3 -c "import sys,json;print(json.load(sys.stdin)['pub'])"; }
field() { python3 -c "import sys,json;print(json.load(sys.stdin)['$1'])"; }
start() { $G serve --data "$T/$1" >"$T/$1.log" 2>&1 & echo $! >"$T/$1.pid"; sleep 1; }
stop() { kill "$(cat "$T/$1.pid")"; rm "$T/$1.pid"; sleep 1; }
wait_height() { for i in $(seq 1 "$3"); do [[ $($G status --data "$T/$1" | field height) -ge $2 ]] && return 0; sleep 1; done; echo "FAIL $1 never reached height $2"; cat "$T"/*.log; exit 1; }

$G init --data "$T/a" --name fede --nat --port $PA --peers 127.0.0.1:$PR1,127.0.0.1:$PR2 --block-interval 2 --sync-interval 3 >/dev/null
GEN=$($G genesis --data "$T/a")
$G init --data "$T/r1" --relay --genesis "$GEN" --port $PR1 --peers 127.0.0.1:$PR2 --sync-interval 3 >/dev/null
$G init --data "$T/r2" --relay --genesis "$GEN" --port $PR2 --peers 127.0.0.1:$PR1 --sync-interval 3 >/dev/null
$G init --data "$T/b" --nat --genesis "$GEN" --port $PB --peers 127.0.0.1:$PR1,127.0.0.1:$PR2 --block-interval 2 --sync-interval 3 >/dev/null
start r1; start r2; start a; start b; sleep 2
[[ $($G status --data "$T/r1" | field role) == relay ]] || { echo "FAIL relay role"; exit 1; }
[[ $($G status --data "$T/r1" | field subscribers) -ge 2 ]] || { echo "FAIL relay has no subscribers"; $G status --data "$T/r1"; exit 1; }
$G put --data "$T/a" --kind decision --payload '{"x":1}' --wait >/dev/null
wait_height b 1 8                                   # a -> r1 (dial) -> b (push)
if $G put --data "$T/r1" --kind note --payload nope 2>/dev/null; then echo "FAIL relay key accepted as author"; exit 1; fi
$G grant member "$(pub "$T/b")" --data "$T/a" --wait >/dev/null; wait_height b 2 8
[[ $($G put --data "$T/b" --kind note --payload '{"from":"b"}' --wait | field height) == 3 ]] || { echo "FAIL b entry via relay"; exit 1; }
stop r1
[[ $($G put --data "$T/b" --kind note --payload '{"via":"r2"}' --wait | field height) == 4 ]] || { echo "FAIL failover to r2"; cat "$T"/*.log; exit 1; }
wait_height a 4 8
stop r2
$G put --data "$T/b" --kind note --payload '{"offline":1}' >/dev/null      # pending on b, no relay alive
sleep 2; [[ $($G status --data "$T/a" | field height) == 4 ]] || { echo "FAIL a advanced with no relay"; $G status --data "$T/a"; $G peers --data "$T/a"; tail -n 5 "$T/a.log" "$T/b.log" "$T/r2.log"; ps -o pid,cmd -C greffe; exit 1; }
start r1; wait_height r1 4 12                                              # relay resyncs from subscribers' hellos
wait_height a 5 20                                                         # b's pending entry reaches a via r1, a seals
wait_height b 5 8
for n in a b r1; do $G verify --data "$T/$n" | grep -q '"ok":true' || { echo "FAIL verify $n"; exit 1; }; done
[[ $($G status --data "$T/a" | field tip) == $($G status --data "$T/b" | field tip) ]] || { echo "FAIL tips differ"; exit 1; }
echo "OK relay: subscribe push, relay key powerless, member via relay, relay failover, no-relay hold, relay recovery, convergence"
