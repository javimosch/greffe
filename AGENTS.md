# greffe — agent notes

- Source is `src/*.src` (loose Go-like MFL), assembled by `build.sh` with machin's `flags.src` + `machweb.src`.
- ONE event loop owns all state (`node_serve` in src/node.src). Goroutines only accept, read, dial and tick; they
  hand back strings over `g_evch`. Keep it that way: it is what makes `machin check` prove the node race-free.
- Chain rules live in src/chain.src and nowhere else (`chain_check` validates, `chain_apply` mutates, `chain_rebuild` replays).
- `./test.sh` is the gate. `machin check greffe.mfl --json` must stay at 0 diagnostics.
- Exit codes: 0 ok, 1 error, 2 usage, 90 verify failed.
