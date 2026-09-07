---
title: Running a node
---

# Running a node

For the person who looks after a server for the group. Everything here was used to run the
reference federation: two validators behind home NAT, two relays on rented VPS.

## Install

Build from source with [machin](https://github.com/javimosch/machin) (`./build.sh`, or
`STATIC=1 ./build.sh` for a binary that runs on any x86_64 Linux), or take a release binary.
Put it at `/root/bin/greffe` (or anywhere on `PATH`). It needs nothing else: no database, no
runtime, one open TCP port (7420 by default).

## Roles and how to start each

**The first validator** (creates the federation):

```
greffe init --name my-federation --port 7420
greffe genesis          # keep this JSON: every other node starts from it
```

**A relay** (public server, no key power). Enable the explorer if the record is meant to be
public:

```
greffe init --relay --ui --genesis '<genesis json>' --port 7420 --peers other-relay:7420
```

**A validator or member node behind NAT**:

```
greffe init --nat --genesis '<genesis json>' --peers relay1:7420,relay2:7420
```

**A node that can reach the first node directly** (same LAN, VPN, or both public):

```
greffe init --join http://first-node:7420
```

Then `greffe key` prints the node's public key; a validator admits it with
`greffe grant member <pub>` or `greffe grant validator <pub>`.

## systemd

`deploy/greffe.service` (validator or member) and `deploy/greffe-relay.service` (relay) are
ready to copy to `/etc/systemd/system/`. They set `Restart=always`, a memory ceiling as a
safety net (a node idles at ~5 MB; the ceiling is 96–128 MB) and `Nice=10`. On an unprivileged
LXC container do not add `PrivateTmp`/`ProtectSystem`: they need mount namespaces the
container denies, and the unit will fail with `226/NAMESPACE`.

For a user (non-root) node: `~/.config/systemd/user/greffe.service` with
`ExecStart=%h/bin/greffe serve --data %h/.greffe`, then `systemctl --user enable --now greffe`
and `loginctl enable-linger $USER` so it survives logout.

## Firewall

Open the node's port inbound on relays and on any node that should be dialled. A `--nat`
node needs no inbound port. On ufw: `ufw allow 7420/tcp`.

## Files

Everything lives in the data directory (`~/.greffe` or `--data`):

| File | What | Back up? |
|---|---|---|
| `node.key` | Ed25519 seed, 0600 | yes, offline — it is the node's identity |
| `config.json` | name, genesis, peers, port, intervals, roles, `ui`, `rate_limit` | yes |
| `chain.jsonl` | the record, one block per line, fsync'd on every append | anywhere; it is public and self-verifying |
| `pending.jsonl` | entries waiting to be sealed | no |
| `peers.json` | peers learned from hellos | no |

To edit `config.json`, stop the node, edit, start. Fields you may set by hand: `peers`,
`nat`, `relay`, `ui`, `rate_limit`, `block_interval`, `sync_interval`. Never change `name`,
`genesis_ts` or `validators` on a running federation: they define the genesis hash, and a
node with a different genesis is a different federation.

## Watching it

- `greffe status` — role, height, weight, tip, validators, members, pending, peers,
  subscribers, resets. Height and tip should match across nodes within seconds of a block.
- `greffe peers` — each peer's last known height and when it last answered.
- `greffe verify` — full re-verification; exit code 90 if the record is broken.
- `journalctl -u greffe -f` — one line per block, per adopted chain, per dropped subscription.
- `GREFFE_DEBUG=1` in the environment logs resident memory every 100 events and each reset.

## Upgrading

Replace the binary and restart the service. The on-disk format (JSON lines) is the
compatibility contract; a new binary re-verifies the chain on start and refuses to run if it
does not validate, so an upgrade cannot silently corrupt a record.

## Memory and load

A node idles at ~5 MB resident and returns there after load. Under 2,000 writes in a few
seconds it peaks between 35 MB (relay) and 80 MB (validator) and settles back; those numbers
come from `bench.sh` in the repository. If resident memory climbs and does not come back,
that is a bug: open an issue with the `GREFFE_DEBUG=1` log.

## When things go wrong

**Two nodes show different tips for more than a minute.** They are on a fork and cannot see
each other. Check that at least one relay is up and both nodes list it in `peers`; check
`greffe peers` on each for `fails`. Once they meet, the heavier chain wins and the other
node logs `adopted chain`.

**A block is rejected in the log.** The reason is printed (`signer is not a validator`,
`duplicate entry`, `hash mismatch`…). A single rejected block from one peer is normal during
a fork; repeated rejections from every peer mean this node's copy is the odd one out: stop it,
move `chain.jsonl` aside, start it, and let it resync from genesis.

**`gc reload failed` and exit code 3.** The node could not re-read its own `chain.jsonl`
during a memory reset. The file is corrupt or truncated; restore it from any other node.

**`cannot bind port`.** Another process holds the port, or a previous instance is still
running.

**A `--nat` node logs `subscription to … dropped` every 15 s.** The relay is unreachable
from that node: firewall, wrong address, or the relay is down.
