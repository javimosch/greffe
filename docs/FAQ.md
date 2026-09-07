---
title: FAQ
---

# FAQ

**Is this a cryptocurrency?** No. There is no token, no mining, no fees, nothing to buy. greffe
records facts; it moves no value.

**Why call it a blockchain then?** Because it is one: entries in blocks, blocks chained by
hash, replicated on every participant's machine, verifiable from the first block by anyone.
That structure is what gives the record its properties. The parts most people associate with
the word — coins, energy use, speculation — are the parts greffe leaves out.

**Who decides who can write?** The group's validators, by signed entries that are themselves
in the record. See [Governance](GOVERNANCE.md).

**Can the record be edited or deleted?** Not without every node noticing. An entry can be
*superseded* by a later entry that says so; the original stays.

**Can it be private?** The record is shared with every node by design, and public if a node
enables the explorer. Put hashes of private documents in it, not the documents.

**How many machines do we need?** Two validators and two relays is a robust minimum. One of
each works for a trial. Members add nodes if they want to; they do not have to.

**What does it cost to run?** A node idles at about 5 MB of memory and no CPU; a rented VPS at
the lowest tier is more than enough for a relay. A federation that records ten facts a day
costs nothing measurable.

**What happens if all validators go offline?** Nothing is lost. Nodes keep serving the record;
new entries wait as pending; sealing resumes when a validator returns.

**What if we lose a key?** Revoke it, admit a new one. Nobody can recover or reset a key,
including the developers.

**Can we use it without the command line?** Reading: yes, through a node's explorer. Writing
requires signing with a key, which today means the CLI. A small signing app is on the
roadmap; contributions welcome.

**Which language is it written in, and why?** [machin](https://github.com/javimosch/machin)
(MFL), which compiles to one static binary with no runtime. The point was a node that a
volunteer can copy to a machine and run, with nothing to install, and that the compiler can
prove free of data races.

**Is it audited?** No. The cryptography is standard (Ed25519, SHA-256) and the consensus rule
is Clique-style proof of authority, but the implementation is young and has one author. Read
[Security](SECURITY.md), run `test.sh` and `test-relay.sh`, read the source — it is short —
and treat it as a proof of concept until it has more eyes on it.
