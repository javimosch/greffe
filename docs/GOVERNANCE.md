---
title: Governance
---

# Governance

greffe decides nothing for the group. It records who the group admitted, and enforces that
only they write. This page is the operating manual for that: how a federation bootstraps,
grows, and handles the awkward cases.

## Bootstrapping

1. The first validator runs `greffe init --name <federation>` and publishes the output of
   `greffe genesis`: the name, a timestamp and the first validator keys. This JSON is the
   federation's birth certificate; everyone else starts from it.
2. Other servers of the umbrella organisation start as validators-to-be with the genesis and
   are admitted: `greffe grant validator <pub>`. Two to five validators, on machines run by
   different people, is the sweet spot.
3. Two relays on public hosts, started with the genesis. They are never granted anything.
4. Each member association starts a node (`--nat` if behind a router), sends its public key
   to the umbrella, and is admitted with `greffe grant member <pub>`.

Every one of those grants is an entry in the record, with the key that made it and the time.

## Roles, precisely

| | may write entries | may seal blocks | may grant/revoke |
|---|---|---|---|
| validator | yes | yes | yes |
| member | yes | no | no |
| full node / relay | no | no | no |

A validator is also a member for writing purposes. Removing the last validator is refused by
every node: the record can always move forward.

## Changing the group

- **Admit**: `greffe grant member <pub>` / `greffe grant validator <pub>`.
- **Revoke**: `greffe revoke member <pub>` / `greffe revoke validator <pub>`. Effective from
  the block that contains the revocation; entries the key wrote before stay valid and visible.
- **Rotate a key**: admit the new key, then revoke the old one. Do it in that order so the
  identity never has zero valid keys.
- **A validator disappears** (server dies, operator leaves): the others keep sealing (its turn
  is skipped after a short wait). Revoke it when it is clear it will not return, so the turn
  rotation is tight again.

## Conventions the group should agree on

greffe imposes no schema on `kind` or `payload`. A federation will want a short written
convention — it can be the first decision recorded. A workable starting set:

| kind | payload | who |
|---|---|---|
| `charter` | `{"title","text_hash","url"}` | validator |
| `decision` | `{"body":"general assembly","date","title","outcome","votes":{"for","against","abstain"}}` | validator or delegate |
| `org.join` / `org.leave` | `{"name","pub","contact_hash"}` | validator |
| `release` | `{"tool","version","sha256","url"}` | maintainer |
| `grant.record` | `{"to","amount","currency","purpose","reference"}` (a fact about a payment, not a payment) | treasurer |
| `incident` | `{"service","started","resolved","summary"}` | operator |
| `attest` | `{"sha256","what","where"}` | anyone |

Put the convention itself in the record as a `charter` entry, and update it the same way.

## Disputes

The record does not settle disputes; it makes them factual. Every claim of "that was never
decided" or "I was admitted before that" can be checked against signed, ordered entries that
every member holds. If a validator wrote something the group disowns, the group records the
disavowal as a new entry and, if needed, revokes the validator — the original stays, with its
signature, as evidence of what happened.
