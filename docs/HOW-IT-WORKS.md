---
title: How greffe works
---

# How greffe works

This page explains greffe in plain language, for the people who will run it or rely on it:
board members, treasurers, volunteers who look after a server. No prior blockchain knowledge
is assumed. The precise rules are in the source; this is the map.

## The problem it solves

A group that shares governance also shares a memory: what the assembly decided, who joined,
what was approved, what was published. Usually that memory lives in one place — one
spreadsheet, one admin's inbox, one SaaS account — and whoever holds it can change it, lose
it, or lock the others out. Everyone else has to trust, and cannot check.

greffe replaces that single copy with a **shared record that every participant holds, that
only grows, and that anyone can check**. If someone alters their copy, the alteration shows.
If someone loses their copy, the others still have it.

## The three things in the record

**Entries** are the facts. An entry says *who* (the author's public key), *when* (a
timestamp), *what kind* (`decision`, `member.join`, `release`… any word the group chooses)
and *what* (the payload: any text, usually JSON). Each entry is signed with the author's
private key, so nobody can write in someone else's name, and nobody can change an entry
afterwards without breaking the signature.

**Blocks** bundle entries and chain them. Every block carries the hash of the previous one,
so the record is a chain: change anything in block 12 and blocks 13, 14, 15… no longer match.
Blocks are sealed by **validators** — the group's own servers — and signed by them.

**Governance entries** are entries that change who is trusted: `validator.add`,
`validator.remove`, `member.add`, `member.remove`, each carrying a public key. Only a
validator may author them, and they are recorded in the chain like everything else. There
is no admin panel, no config file that quietly grants rights: **who may write is itself part
of the record**.

## Who does what

| Role | Who, typically | Can do |
|---|---|---|
| Validator | the association's servers (2–5) | seal blocks, admit or remove members and validators, write entries |
| Member | each member association or person with a key | write entries |
| Full node | anyone (a member's laptop, a relay) | hold and verify the whole record, serve it |
| Reader | anyone at all | open a node's explorer or API, run `greffe verify` |

## How a fact gets in

1. A member runs `greffe put --kind decision --payload '…'`. The CLI signs the entry with the
   key in `~/.greffe/node.key` and hands it to the local node.
2. The node checks the signature and that the author is a known member, then queues the entry
   as *pending* and tells its peers.
3. The validator whose turn it is seals a block with everything pending (the turn rotates
   through the sorted list of validators; if the in-turn validator is down, the next one waits a
   few seconds and seals instead). No block is ever sealed empty.
4. The block is announced; every node checks it — hash, signature, every entry's signature,
   every author's right to write — and appends it.
5. `--wait` on the `put` returns when the entry is in a block, with its height.

## When two validators seal at once

It happens: two validators, both with pending entries, both convinced it is their moment.
Each node then holds a different "latest block". greffe resolves this deterministically:
an in-turn block counts 2, an out-of-turn block counts 1, the chain with the higher total
wins, and a tie goes to the lower block hash. Every node applies the same rule to the same
data and lands on the same chain. Entries from the losing block are not lost: they go back
to pending and are sealed again.

There is one thing fork choice will never do: rewrite settled history. A node refuses any
fork that would replace more than `max_reorg` blocks (fifty by default), however heavy it is.
So a validator that re-sealed the past, even with its own valid key, would be ignored by every
node that holds the honest record.

## Nodes behind home routers

Most members' machines cannot be reached from the internet. Such a node starts with `--nat`
and a list of **relays**: public nodes it can reach. It keeps a connection open to each relay,
so new blocks are pushed to it at once, and sends its own entries and blocks out through
them. A relay is an ordinary full node with no special power — it holds no validator or
member key, so it cannot forge anything; at worst it could stay silent, which is why a group
runs two.

## What "verify" actually checks

`greffe verify` (or the explorer's button) re-reads the whole record from the first block and
checks, for every block: the height and previous-hash link, the block hash, the sealer's
signature and that the sealer was a validator *at that point in the chain*; and for every
entry: the id, the signature, that the author was allowed to write *at that point*, and that
it appears only once. Then it reports the tip. If any check fails, it names the block.

## What greffe is not

- Not a currency. Nothing is minted, priced or transferred.
- Not anonymous. Every writer is a known key admitted by the group.
- Not a database. It records facts in order; searching and reporting are for tools that read it.
- Not proof against the group itself. If the validators collude, they can write anything —
  but they cannot do it invisibly, and they cannot rewrite what was already replicated to
  members. See [Security](SECURITY.md).
