# greffe

A lightweight, transparent, append-only registry for a federation of associations,
written in [machin](https://github.com/javimosch/machin) (MFL). One static binary
(~5 MB), ~5 MB resident memory, one TCP port, no database, no mining, no money.

*Greffe* is the French registry where associations are declared. This one is shared:
the association's servers seal it, every member association can add its own machine
as an extra node, and anyone can re-verify the whole record from genesis.

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
- **Peers**: nodes dial each other directly (LAN, Tailscale, public IP). A node behind
  NAT dials the association's servers; they learn it from its hello and pull from it.
  Push (announce) + pull (sync every `sync_interval`) over short-lived TCP connections.

## Quick start

```sh
./build.sh                                  # needs machin; STATIC=1 for a portable binary
greffe init --name my-federation --port 7420          # first validator (keys in ~/.greffe)
greffe serve                                          # or the systemd unit in deploy/
# on another machine:
greffe init --join http://first-node:7420 && greffe serve
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

## Status

v0.1.0 — proof of concept, live on two nodes (a laptop and an LXC container over
Tailscale). `./test.sh` covers seal, sync, the membership gate, grants, two-validator
round-robin, partition catch-up and restart persistence. Not yet: a relay for two nodes
that are both behind NAT, TLS between peers (use Tailscale/WireGuard), entry batching limits per author.
