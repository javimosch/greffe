---
title: Security and threat model
---

# Security and threat model

Credibility comes from saying exactly what a tool protects against and what it does not.
This page is that list. Read it before relying on greffe for anything that matters.

## What is guaranteed, and by what

| Property | Mechanism | Holds against |
|---|---|---|
| An entry cannot be forged in someone's name | Ed25519 signature over the entry id | anyone without the author's private key |
| An entry cannot be altered after the fact | id = SHA-256 of the content; signature over the id | anyone, including the author |
| History cannot be rewritten unnoticed | hash chain; block signatures; every node keeps a copy | anyone who does not control every copy |
| Only admitted keys can write | membership rules replayed from genesis on every node | outsiders; revoked members |
| Only validators can seal or change membership | validator set replayed from genesis | members; relays; outsiders |
| Any reader can check all of the above | `greffe verify`, the explorer, the raw `chain.jsonl` | trust in any single operator |

## What is not guaranteed

**Colluding validators.** If a majority of the validators' operators agree to write false
facts, the protocol will record them. greffe makes this *visible* (every block names its
sealer, every governance change is in the record) and *bounded* (they cannot alter what
members already hold), but it does not prevent it. The defence is organisational: keep
validators on machines run by different people, and keep members' copies.

**Withholding.** A validator or relay can refuse to relay entries or blocks. With two or more
of each, this only delays; with one, it stalls. Run at least two validators and two relays.

**Key loss and key theft.** A lost private key means that identity can no longer write; the
group revokes it (`greffe revoke member <pub>`) and admits a new one. A stolen key can write
in the victim's name until it is revoked — entries written in between stay in the record,
marked with that key and a timestamp, and the revocation is recorded next to them. There is
no key recovery by design: nobody, including the validators, can sign for someone else.

**Timestamps.** The `ts` in an entry is set by the author's clock and is not verified beyond
"a block cannot be older than its parent". Treat it as the author's claim; block order is the
reliable ordering.

**Confidentiality.** The record is public to every node and, if the explorer is enabled, to
everyone. Do not put personal data or secrets in a payload. Record a SHA-256 hash of a
document plus where it lives; the document itself stays where access can be controlled.

**Network privacy.** Peer traffic is plain TCP: JSON lines that are already public and
signed. An observer learns which nodes talk, not more than the record already shows. If that
matters, run peers over Tailscale or WireGuard; TLS between peers is on the roadmap.

**Denial of service.** Public relays limit requests per client IP (300 per 10 seconds by
default) and cap message sizes, subscribers and pending entries. A determined attacker can
still exhaust a small VPS's bandwidth; greffe does not try to be a firewall.

## Key handling

- Each node has one Ed25519 seed in `<data>/node.key`, created by `greffe init`, mode 0600.
  The public key is what the group admits.
- The CLI signs entries with the key in the data directory it is pointed at (`--data`,
  `$GREFFE_DATA`, or `~/.greffe`). Keep signing keys on machines their owner controls; a
  relay needs a key only to have an identity and should never be granted anything.
- Back up `node.key` offline. Back up `chain.jsonl` anywhere: it is public and self-verifying.
- Rotate a key by admitting the new one, then revoking the old one — two governance entries.

## Reporting a problem

Open an issue at <https://github.com/javimosch/greffe/issues>. For anything that could let
someone forge or alter the record, say so in the title; those are handled first.
