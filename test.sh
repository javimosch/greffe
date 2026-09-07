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
$G init --data "$T/a" --name t --port $PA --block-interval 2 --sync-interval 2 --ui --rate-limit 40 >/dev/null; start a
$G init --data "$T/b" --port $PB --join http://127.0.0.1:$PA --block-interval 2 --sync-interval 2 >/dev/null; start b
[[ $($G put --data "$T/a" --kind decision --payload '{"x":1}' --wait | field height) == 1 ]] || { echo "FAIL seal"; exit 1; }
sleep 3; [[ $($G status --data "$T/b" | field height) == 1 ]] || { echo "FAIL sync to b"; exit 1; }
if $G put --data "$T/b" --kind note --payload no 2>/dev/null; then echo "FAIL non-member accepted"; exit 1; fi
$G grant member "$(pub "$T/b")" --data "$T/a" --wait >/dev/null; sleep 3
[[ $($G put --data "$T/b" --kind note --payload hi --wait | field height) == 3 ]] || { echo "FAIL member put via gossip"; exit 1; }
$G grant validator "$(pub "$T/b")" --data "$T/a" --wait >/dev/null; sleep 3
$G put --data "$T/b" --kind note --payload h5 --wait >/dev/null
EXP=$(python3 -c "import sys; v=sorted(sys.argv[1:]); print(v[5 % 2])" "$(pub "$T/a")" "$(pub "$T/b")")
[[ $($G block 5 --data "$T/a" | field signer) == "$EXP" ]] || { echo "FAIL block 5 not sealed by the in-turn validator"; cat "$T/a.log" "$T/b.log"; exit 1; }
[[ $($G status --data "$T/a" | field weight) == 10 ]] || { echo "FAIL weight: every block should be in-turn (2)"; exit 1; }
kill "$(cat "$T/a.pid")"; sleep 1
$G put --data "$T/b" --kind note --payload h6 --wait >/dev/null   # b seals out-of-turn alone
start a; sleep 6
[[ $($G status --data "$T/a" | field height) == 6 ]] || { echo "FAIL a catch-up after partition"; exit 1; }
kill "$(cat "$T/b.pid")"; sleep 1; start b; sleep 1
$G verify --data "$T/a" | grep -q '"ok":true' && $G verify --data "$T/b" | grep -q '"ok":true' || { echo "FAIL verify"; exit 1; }
[[ $(wc -l <"$T/b/chain.jsonl") == 7 ]] || { echo "FAIL persistence"; exit 1; }
# explorer: served on a only (opt-in); guide stays the default for non-browser clients
curl -s -H "Accept: text/html" http://127.0.0.1:$PA/ | grep -q "<title>greffe explorer" || { echo "FAIL explorer not served on /"; exit 1; }
curl -s http://127.0.0.1:$PA/ui | grep -q "greffe explorer" || { echo "FAIL explorer not served on /ui"; exit 1; }
curl -s http://127.0.0.1:$PA/ | grep -q "^greffe " || { echo "FAIL guide not served to non-browser"; exit 1; }
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$PB/ui | grep -q 404 || { echo "FAIL explorer served although disabled"; exit 1; }
curl -s "http://127.0.0.1:$PA/entries?kind=gov" | python3 -c "import sys,json; es=json.load(sys.stdin); assert len(es)==2 and all(e['kind'].startswith(('member.','validator.')) for e in es)" || { echo "FAIL gov filter"; exit 1; }
curl -s "http://127.0.0.1:$PA/entries?author=$(pub "$T/b")" | python3 -c "import sys,json; es=json.load(sys.stdin); assert len(es)>=1 and all(e['author']=='$(pub "$T/b")' for e in es)" || { echo "FAIL author filter"; exit 1; }
# rate limit: loopback is exempt, so hit the node over the LAN address with a burst of 60 (limit 40/10s)
LAN=$(hostname -I | awk '{print $1}')
codes=$(for i in $(seq 1 60); do curl -s -o /dev/null -w "%{http_code}\n" http://$LAN:$PA/health; done | sort | uniq -c | tr -s ' ' | tr '\n' ';')
echo "$codes" | grep -q "429" || { echo "FAIL no 429 in burst: $codes"; exit 1; }
echo "$codes" | grep -q " 40 200" || { echo "FAIL expected exactly 40 x 200: $codes"; exit 1; }
echo "OK: seal, sync, membership gate, grant, 2-validator round-robin, partition catch-up, restart persistence, explorer opt-in, gov/author filters, rate limit"
