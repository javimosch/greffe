# greffe — vision and north star

## One sentence

**greffe is a lightweight blockchain for associations, cooperatives and collectives — any group that
runs on trust and needs a shared record nobody can quietly rewrite.**

## Why a blockchain, and why not the usual kind

Groups that share governance also share a memory: who decided what, when a member joined, which
tool release was approved, what was paid to whom. Today that memory lives in one organisation's
spreadsheet, one admin's inbox, one SaaS account. Whoever holds it can edit it, lose it, or lock the
others out. The others have to trust, and cannot verify.

A blockchain fixes exactly that: an append-only record, replicated on every participant's machine,
where each entry is signed by its author and each block is chained by hash, so tampering is visible
and the whole history can be re-verified by anyone from the first block.

What most blockchains add on top — a currency, mining, staking, gas, a global permissionless
network — is what makes them expensive, slow and alien to a volunteer-run collective. greffe keeps
the record and drops the rest:

- **No money.** Nothing is minted, priced or traded. greffe is a ledger of facts, not of value.
- **No mining, no staking.** The group already knows who it trusts: its own servers. Those are the
  validators, in round-robin (proof of authority). Adding one is a signed entry, not a fork.
- **No global chain.** Every federation runs its own chain, with its own genesis. Scale is measured
  in dozens of nodes, not millions.
- **No empty blocks.** An idle collective costs nothing to run. A node idles at ~5 MB of memory.

## Who it is for

- **Federations of associations**: an umbrella body and its member associations, each keeping a
  node, each able to prove what the federation decided.
- **Cooperatives**: worker, housing, energy or food co-ops, where members are owners and the
  register of decisions, membership and contributions must be visible to all of them.
- **Collectives and commons**: open-source projects, community networks, mutual-aid groups — anyone
  who provides shared tools or infrastructure and wants its governance on the record.

The common trait is that **transparency is a value, not a compliance requirement**, and that the
group has a handful of machines and a lot of goodwill, not a budget for infrastructure.

## Principles

1. **Anyone can verify, few need to run anything.** One static binary, one port, one command
   (`greffe verify`) re-checks every signature and hash from genesis. A member who only wants to
   read can use any node's HTTP API; a member who wants to reinforce the record adds a machine.
2. **Authority is explicit and on the record.** Who may seal blocks and who may write entries is
   itself written in the chain, as signed governance entries. There is no admin panel and no
   out-of-band configuration that changes who is trusted.
3. **Gentle by design.** Built to run on a Raspberry-class box, a small VPS or a member's laptop
   behind NAT. Memory is flat under load; idle costs nothing; a dead server never stalls the group.
4. **No single point of failure — including relays.** Nodes behind NAT meet through public
   relays, but a relay holds no key, cannot forge anything, and can only withhold; two relays make
   withholding pointless. Fork choice is deterministic, so nodes converge without a coordinator.
5. **Agent-first, human-readable.** Every command prints JSON with stable exit codes, every node
   serves its own guide, and the record is plain text (one JSON line per block) that a human can
   read with `cat`.
6. **Boring cryptography, no novelty.** Ed25519 signatures, SHA-256 hashes, and a consensus rule
   (Clique-style proof of authority) that has run in production elsewhere for years.

## North star

**A federation of ten associations, spread across a region, runs its shared registry on the
machines it already owns — three association servers as validators, two rented VPS as relays,
and a dozen members' laptops as extra nodes — and any member, or any outsider, can download one
binary and prove in seconds that the record of decisions, memberships and releases is complete
and untampered.**

When that is true and boring, greffe has done its job.

## What "transparent" means here

- Every entry names its author (a public key the group has admitted) and is signed.
- Every block names its sealer and is signed; the sealing order is a public rule.
- Governance changes are entries like any other, visible in the same history.
- The whole record is public by default. Confidential data does not belong in it; store a
  hash of a document instead of the document when the content must stay private.

## Non-goals

- Tokens, payments, smart contracts, DeFi of any kind.
- Permissionless membership or anonymous writers. Authority is granted by the group.
- Byzantine fault tolerance against validators that actively collude. greffe assumes validators
  are the group's own servers; a malicious validator is a governance problem (revoke it) before
  it is a protocol problem.
- Being a database. greffe records facts; querying, dashboards and search live in tools that read
  the chain.

## Roadmap, in order of usefulness

1. **Confidentiality where needed**: an entry kind that carries only a hash plus a pointer, and a
   convention for encrypted payloads for members only.
2. **Rate limits and quotas** on public relays and per author, so a hijacked member key cannot
   flood the record.
3. **TLS between peers** without a reverse proxy, for federations that cannot run WireGuard.
4. **Pruning**: keep old blocks on disk only, so a ten-year-old chain still fits in a few MB of
   memory.
5. **Readers**: a static site generator and a small viewer that turn a chain into a browsable
   history of a group's decisions.
6. **Multi-language guides** for the operators of associations who will never read a README in
   English.

## About the name

*Greffe* is the French word for the registry office where associations and companies are declared.
The name is a nod to that role — a public office of record — not to a country: greffe is meant for
any group, anywhere, whose members deserve to see and verify their own record.
