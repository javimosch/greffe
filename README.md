# greffe

**A lightweight blockchain for associations, cooperatives and collectives — any group
where transparency matters and nobody should be able to quietly rewrite the record.**

Written in [machin](https://github.com/javimosch/machin) (MFL): one static binary (~5 MB),
~5 MB resident memory, one TCP port, no database. It keeps what a blockchain is for — an
append-only, signed, hash-chained record replicated on every member's machine and
verifiable by anyone from genesis — and drops what makes blockchains expensive: no money,
no mining, no staking, no global network. The group's own servers seal blocks; any member
can add a machine as an extra node.

See [docs/VISION.md](docs/VISION.md) for the north star and principles.

## Model

- **Entries** are signed records: `{id, author, ts, kind, payload, sig}` with
  `id = sha256(author|ts|kind|payload)` and an Ed25519 signature over the id.
  `kind` is free text (`decision`, `tool.release`, `grant`, …); `payload` is any text, JSON encouraged.
- **Blocks** hold entries and chain by hash. Only **validators** seal blocks, in
  Clique-style round-robin: the in-turn validator seals immediately, the others wait
  `block_interval × distance` seconds so an offline server never stalls the chain.
  No empty blocks: an idle federation costs nothing.
- **Fork choice**: highest total weight (in-turn block = 2, out-of-turn = 1), ties by lowest tip hash.
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
```

Every command prints JSON; `greffe guide` or `GET /` explains the HTTP API
(`/status /peers /blocks /entries /pending /verify`, `POST /entries`).

## Files

`~/.greffe/` (or `--data`, or `$GREFFE_DATA`): `node.key` (Ed25519 seed, 0600),
`config.json`, `chain.jsonl` (one block per line, fsync'd), `pending.jsonl`, `peers.json`.

## Name

*Greffe* is the registry office where associations are declared in some countries; the name
points at that role — a public office of record — not at a place. greffe is for any group,
anywhere.

## Status

v0.2.0 — proof of concept live on four nodes: two NAT'd validators (a laptop, an LXC
container) that only meet through two public relays (Hetzner, DigitalOcean). `./test.sh`
covers seal, sync, the membership gate, grants, two-validator round-robin, partition
catch-up and restart persistence; `./test-relay.sh` covers subscriptions, relay failover,
no-relay hold, relay recovery and fork convergence through relays; `./bench.sh` (and
`RELAY=1 ./bench.sh`) drive 2,000 writes and record RSS to bench.csv.
Not yet: TLS between peers (use Tailscale/WireGuard), per-IP rate limits on relays,
per-author entry quotas, pruning of old blocks from memory.
