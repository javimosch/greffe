---
title: Use cases
---

# Use cases

Each of these is a real shape of group, with the entry conventions it would use and what a
member can verify. The first one is playable: `examples/federation.sh` runs it on your
machine in under a minute.

## 1. A federation of associations — the reference case

**Who**: an umbrella association with ten member associations across a region. The umbrella
runs three servers; two members add their own machines.

**What goes in the record**

- `org.join` when a member association is admitted (its name, its public key, a hash of the
  signed membership form).
- `decision` for every general-assembly resolution: title, date, outcome, vote counts, hash of
  the minutes PDF.
- `release` when the federation publishes a shared tool: name, version, SHA-256 of the
  artifact, download URL.
- `grant.record` when the federation pays a subsidy to a member: recipient, amount, purpose,
  bank reference. (A fact about money, recorded; greffe moves no money.)

**What a member can check**: that its own admission is on record; that a decision it
remembers has the votes it remembers; that the binary it downloaded matches the recorded
hash; that every subsidy paid this year is listed, and by whom.

**Playable**: `./examples/federation.sh` starts an umbrella validator, two member nodes and a
relay locally, admits the members, records a charter, a decision, a release and a subsidy,
has a member verify the whole record, shows a non-member being refused, and revokes a member.

## 2. A housing or food cooperative

**Who**: sixty member-owners, a board of five, one small server at the building plus two
board members' laptops.

**What goes in**: `member.join` / `member.leave` with a hash of the share certificate;
`decision` for board and assembly votes; `contribution` for work hours or deliveries a member
logs (`{"member","hours","task","date"}`), countersigned later by a board `attest`;
`maintenance` for repairs (what, cost, contractor).

**Why a chain and not the co-op's spreadsheet**: members are owners; the register of who owns
what and who decided what must survive a board change and a laptop theft, and be checkable by
any member without asking the board.

## 3. An open-source collective

**Who**: maintainers spread across countries, a small foundation that receives donations.

**What goes in**: `release` with the artifact hash for every published version (so a download
can be checked against a record nobody can quietly edit); `maintainer.grant` /
`maintainer.revoke` mirrored as governance entries; `grant.record` for every disbursement
from the donation pool; `decision` for RFC outcomes.

**Why**: supply-chain attestations and money trails are the two things a project is asked to
prove years later, and both are usually scattered across CI logs and bank exports.

## 4. A community network or shared infrastructure

**Who**: a mesh network, a shared server room, a tool library — anything where members own
pieces of a whole.

**What goes in**: `asset` for each node or machine (owner key, location, serial hash);
`incident` with start, end and summary; `access.grant` / `access.revoke` for who may
administer what; `decision` for policy changes.

**Why**: when something breaks at 3 a.m., "who owns this and who touched it last" should be
one query on a record nobody can edit after the fact.

## 5. Document notarisation across organisations

**Who**: several organisations that exchange agreements, minutes or reports and want to be
able to prove *this exact document existed on this date* without a notary.

**What goes in**: `attest` entries — `{"sha256","what","where"}` — signed by the organisation
that holds the document. The document itself never enters the record.

**Why**: later, anyone with the document can hash it and find the matching entry, its author
and its block; changing a comma in the document breaks the match.

## What all five have in common

- A handful of servers the group already has, plus volunteers' machines.
- Facts that must outlive the people who recorded them.
- Members who should not have to *ask* to check the record.
- No need for a currency, and no budget for one.
