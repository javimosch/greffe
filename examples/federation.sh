#!/usr/bin/env bash
# A federation of associations, played end to end on one machine in about a minute.
#
#   umbrella   — the federation's server: first validator, creates the genesis
#   relay      — a public full node (here: just another local process), no key power
#   assoc-a    — a member association's node, behind NAT in real life (--nat)
#   assoc-b    — another member association
#
# Needs ./greffe (run ./build.sh first). Everything lives in a temp dir that is removed at exit.
set -euo pipefail
cd "$(dirname "$0")/.."
G=${GREFFE_BIN:-./greffe}
T="${TMPDIR:-/tmp}/greffe-federation-$$"; mkdir -p "$T"
trap 'kill $(cat "$T"/*.pid 2>/dev/null) 2>/dev/null || true; rm -rf "$T"' EXIT
say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
run() { printf '  $ %s\n' "$*"; "$@"; }
pub() { $G key --data "$T/$1" | python3 -c "import sys,json;print(json.load(sys.stdin)['pub'])"; }
start() { $G serve --data "$T/$1" >"$T/$1.log" 2>&1 & echo $! >"$T/$1.pid"; }
node() { local n=$1; shift; local c=$1; shift; $G "$c" --data "$T/$n" "$@"; }
put() { local n=$1; shift; $G put --data "$T/$n" "$@" --wait | python3 -c "import sys,json; d=json.load(sys.stdin); print('  -> sealed in block', d['height'], '| id', d['id'][:16]+'…')"; }

say "1. The umbrella association creates the federation and publishes its genesis"
run $G init --data "$T/umbrella" --name "federation-of-associations" --port 7601 --block-interval 2 --sync-interval 2 >/dev/null
GEN=$($G genesis --data "$T/umbrella"); echo "  genesis: $GEN"
start umbrella; sleep 1

say "2. A public relay starts from that genesis (it holds no key power)"
run $G init --data "$T/relay" --relay --ui --genesis "$GEN" --port 7600 --peers 127.0.0.1:7601 --sync-interval 2 >/dev/null
start relay; sleep 1

say "3. Two member associations start nodes behind NAT, knowing only the relay"
for n in assoc-a assoc-b; do
  run $G init --data "$T/$n" --nat --genesis "$GEN" --port $((7602 + ${#n})) --peers 127.0.0.1:7600 --block-interval 2 --sync-interval 2 >/dev/null
  start $n
done
sleep 2
echo "  assoc-a key: $(pub assoc-a)"; echo "  assoc-b key: $(pub assoc-b)"

say "4. The umbrella records the charter (a hash of the PDF, not the PDF) and admits both members"
put umbrella --kind charter --payload '{"title":"Charter v1","text_sha256":"9f2c…","url":"https://example.org/charter-v1.pdf"}'
run $G grant member "$(pub assoc-a)" --data "$T/umbrella" --wait >/dev/null; echo "  -> assoc-a admitted"
run $G grant member "$(pub assoc-b)" --data "$T/umbrella" --wait >/dev/null; echo "  -> assoc-b admitted"
sleep 3

say "5. A general-assembly decision, a tool release and a subsidy are recorded"
put umbrella --kind decision --payload '{"body":"general assembly","date":"2026-09-07","title":"Adopt a shared registry","outcome":"adopted","votes":{"for":9,"against":0,"abstain":1}}'
put assoc-a  --kind release  --payload '{"tool":"formulaire-adhesion","version":"2.1.0","sha256":"e3b0c442…","url":"https://example.org/dl/2.1.0.tar.gz"}'
put umbrella --kind grant.record --payload '{"to":"assoc-b","amount":1500,"currency":"EUR","purpose":"summer camp 2026","reference":"SEPA-2026-0912"}'

say "6. assoc-b, on its own machine, verifies the entire record from genesis"
sleep 3
node assoc-b verify
node assoc-b entries --kind decision | python3 -c "import sys,json; [print('  decision in block', e['height'], ':', json.loads(e['payload'])['title']) for e in json.load(sys.stdin)]"

say "7. An outsider with a fresh key tries to write — refused by every node"
$G init --data "$T/outsider" --nat --genesis "$GEN" --port 7620 --peers 127.0.0.1:7600 >/dev/null
$G put --data "$T/outsider" --node http://127.0.0.1:7600 --kind decision --payload '{"title":"I am in charge now"}' 2>&1 | sed 's/^/  relay says: /' || true

say "8. Governance is on the record: who admitted whom, and when"
node relay entries --kind gov | python3 -c "import sys,json; [print('  block', e['height'], e['kind'], 'subject', e['payload'][:12]+'…', 'by', e['author'][:12]+'…') for e in json.load(sys.stdin)]"

say "9. assoc-b leaves the federation: its key is revoked, its past entries stay"
run $G revoke member "$(pub assoc-b)" --data "$T/umbrella" --wait >/dev/null; sleep 3
if $G put --data "$T/assoc-b" --kind decision --payload '{"title":"still here?"}' 2>/dev/null; then echo "  UNEXPECTED: revoked member could write"; exit 1; else echo "  -> assoc-b can no longer write; its earlier entries remain in the record"; fi

say "10. Every node agrees on the same record"
for n in umbrella relay assoc-a assoc-b; do node $n status | python3 -c "import sys,json; d=json.load(sys.stdin); print('  ' + '$n'.ljust(9), d['role'].ljust(9), 'height', d['height'], 'tip', d['tip'][:16]+'…')"; done
echo; echo "The relay's explorer is at http://127.0.0.1:7600/ui while this script waits. Press Enter to tear everything down."
[[ -t 0 ]] && read -r _ || true
