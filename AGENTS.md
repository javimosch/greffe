# greffe — agent notes

- Source is `src/*.src` (loose Go-like MFL), assembled by `build.sh` with machin's `flags.src` + `machweb.src`.
- ONE event loop owns all state (`node_serve` in src/node.src). Goroutines only accept, read, dial and tick; they
  hand back strings over `g_evch`. Keep it that way: it is what makes `machin check` prove the node race-free.
- Chain rules live in src/chain.src and nowhere else (`chain_check` validates, `chain_apply` mutates, `chain_rebuild` replays).
- `./test.sh` is the gate. `machin check greffe.mfl --json` must stay at 0 diagnostics.
- Exit codes: 0 ok, 1 error, 2 usage, 90 verify failed.
- Memory rules (machin): a parsed Block is ~90x its JSON, so `Chain` holds raw lines + `Head`s and every
  parse of entries happens inside `arena { }` with only strings/ints escaped. Long-lived string-keyed maps
  are globals made once (`g_included`, `g_byhash`, ...) and CLEARED on reload — a map made in the main
  goroutine is malloc-backed and survives `arena_reset()`, so re-making it leaks the old one. Transient
  chain rebuilds (fork candidates, verify) go through `chain_judge`, which runs inside an arena.
- `./bench.sh 2000 20` / `RELAY=1 ./bench.sh` are the leak gates: peak should stay < 100 MB and RSS must
  come back down after the run (bench.csv). `GREFFE_DEBUG=1` logs RSS per 100 events and each reset.
