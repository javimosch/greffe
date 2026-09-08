# greffe

**A lightweight blockchain for associations, cooperatives and collectives — any group
where transparency matters and nobody should be able to quietly rewrite the record.**

Written in [machin](https://github.com/javimosch/machin) (MFL): one static binary (~5 MB),
~5 MB resident memory, one TCP port, no database. It keeps what a blockchain is for — an
append-only, signed, hash-chained record replicated on every member's machine and
verifiable by anyone from genesis — and drops what makes blockchains expensive: no money,
no mining, no staking, no global network. The group's own servers seal blocks; any member
can add a machine as an extra node.

Documentation for humans, at <https://javimosch.github.io/greffe/>:
[How it works](docs/HOW-IT-WORKS.md) · [Security & threat model](docs/SECURITY.md) ·
[Running a node](docs/OPERATIONS.md) · [Governance](docs/GOVERNANCE.md) ·
[Use cases](docs/USE-CASES.md) · [FAQ](docs/FAQ.md) · [Vision](docs/VISION.md).
`examples/federation.sh` plays the reference use case locally in about a minute.
In real use: the [matériauthèque of the Cœur des Bauges](https://enbauges.fr/materiautheque)
records every object given or lent between residents in a public greffe
[register](https://enbauges.fr/registre/ui).

## Model

- **Entries** are signed records: `{id, author, ts, kind, payload, sig}` with
  `id = sha256(author|ts|kind|payload)` and an Ed25519 signature over the id.
  `kind` is free text (`decision`, `tool.release`, `grant`, …); `payload` is any text, JSON encouraged.
- **Blocks** hold entries and chain by hash. Only **validators** seal blocks, in
  Clique-style round-robin: the in-turn validator seals immediately, the others wait
  `block_interval × distance` seconds so an offline server never stalls the chain.
  No empty blocks: an idle federation costs nothing.
- **Fork choice**: highest total weight (in-turn block = 2, out-of-turn = 1), ties by lowest tip hash.
  **Settled history is protected**: a node refuses any fork that would rewrite more than
  `max_reorg` blocks (default 50), whatever its weight — so a validator cannot re-seal the past
  and have honest nodes adopt it.
- **Governance is on-chain**: `validator.add|remove` and `member.add|remove` entries
  (payload = public key) signed by a validator. Genesis fixes the name, timestamp and
  first validators; everything after is recorded in the chain itself.
- **Peers**: nodes dial each other directly (LAN, Tailscale, public IP). Push (announce)
  + pull (sync every `sync_interval`) over short-lived TCP connections.
- **Relays for NAT'd nodes**: a chain needs no connection forwarder — any public full node
  is a meeting point, because every block and entry is signed. `greffe init --relay` marks
  a public node as a relay (no key power: it cannot forge, only withhold, which several
  relays defeat). `greffe init --nat --peers relay1:7420,relay2:7420` marks a node that
  cannot be dialled: it advertises no port, keeps one long-lived subscription per relay for
  pushed blocks/entries, and pulls/pushes over its own outbound dials. Relays sync with each
  other like any peers; fork choice reconciles them, so they need no coordination.
- **Public explorer (opt-in)**: `greffe init --ui` (or `"ui": true`) serves a read-only explorer
  at `/ui` on the same port — overview, blocks, entries with kind/author filters, a governance
  view, pending, peers, and a "verify from genesis" button. It is one HTML page baked into the
  binary that calls the JSON API; writes stay in the CLI, where the keys are.
- **Rate limit**: `rate_limit` requests per client IP per 10 s (default 300, loopback exempt);
  over the limit a client gets HTTP 429 or a `rate limited` peer reply. Public relays should
  keep it on.
- **One domain, several nodes**: `--base-path /registre` serves the API and explorer under a
  prefix, so a site can front its register with one reverse-proxy rule and read it same-origin.
- **Memory**: blocks are held as raw JSON lines + small headers; entries are parsed on demand
  inside scoped arenas, and the single-actor loop resets its arena when RSS grows (state is
  rebuilt from disk). A node stays at a few MB idle and tens of MB under sustained writes.

## Quick start

```sh
./build.sh                                  # needs machin; STATIC=1 for a portable binary
greffe init --name my-federation --port 7420          # first validator (keys in ~/.greffe)
greffe serve                                          # or the systemd unit in deploy/
# on another machine that can reach the first one:
greffe init --join http://first-node:7420 && greffe serve
# on a public server (relay) / a machine behind NAT, starting from the published genesis:
greffe genesis                                        # -> {"name","genesis_ts","validators","hash"}
greffe init --relay --genesis '<that json>' --port 7420 --peers other-relay:7420
greffe init --nat   --genesis '<that json>' --peers relay1:7420,relay2:7420
greffe key                                            # its public key
# back on the first node:
greffe grant validator <pub>      # or: greffe grant member <pub>
# anywhere that holds a member/validator key:
greffe put --kind decision --payload '{"title":"adopt greffe"}' --wait
greffe entries --kind decision
greffe verify                                         # exit 0 ok / 90 broken
greffe init --relay --ui ...                          # relay with the public explorer at /ui
greffe init --ui --put-token auto --base-path /registre   # a site's register: explorer + server-side writes under one path
```

Server-side apps that should record facts with a node's own key (a website, a bot) get an authenticated
`POST /put {kind,payload}` when the node is started with `--put-token` (off otherwise).

Every command prints JSON; `greffe guide` or `GET /` explains the HTTP API
(`/status /peers /blocks /entries?kind=&author= /pending /verify`, `POST /entries`, `/ui`).

## Files

`~/.greffe/` (or `--data`, or `$GREFFE_DATA`): `node.key` (Ed25519 seed, 0600),
`config.json`, `chain.jsonl` (one block per line, fsync'd), `pending.jsonl`, `peers.json`.

## Name

*Greffe* is the registry office where associations are declared in some countries; the name
points at that role — a public office of record — not at a place. greffe is for any group,
anywhere.

## Status

v0.4.0. In production for one federation: the register of the
[matériauthèque of the Cœur des Bauges](https://enbauges.fr/materiautheque), two validators on
two machines (a site server and an independent VPS), served at
[enbauges.fr/registre](https://enbauges.fr/registre/ui). An earlier four-node proof-of-concept
federation across a laptop, an LXC container and two relays was retired once the real one ran.

Gates: `test.sh` (seal, sync, membership gate, grants, two-validator round-robin, partition
catch-up, restart persistence, explorer, filters, `/put`, rate limit), `test-relay.sh`
(subscriptions, relay failover, no-relay hold, relay recovery, fork convergence through relays),
`test-reorg.sh` (a heavier rewrite of settled history is refused), `bench.sh` and
`RELAY=1 ./bench.sh` (2,000 writes, RSS recorded to bench.csv). `machin check` reports zero
data-race diagnostics.

Not yet: TLS between peers (use Tailscale/WireGuard), per-author entry quotas, pruning of
old blocks from memory.
