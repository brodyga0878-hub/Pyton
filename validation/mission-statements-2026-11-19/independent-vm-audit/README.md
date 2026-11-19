# Independent public VM/State audit

The read-only implementation review and separate public-API harness exercise
Core21, composed statement execution and the owned VM transaction. The current
run has **83 checks and 0 failures**; `report.json` records every condition and
the exact implementation hashes used. `audit.log` contains the actual run.

Run from the project root:

```sh
godot --headless --path . --script validation/mission-statements-2026-11-19/independent-vm-audit/audit.gd
```

The harness verifies:

- Complete cold numeric normalization of definitions, registry nodes, market,
  text and shared owners; no persisted invocation cursor/duplicate task record.
- Explicit 156-byte private frame seeds, binary definedness masks, FIFO nested
  entry and private unwind order; no invented seed for recursive F41.
- Exact world frames, immutable source resources, actual registry journals,
  bounded heap transitions, and failure atomicity of the owned transaction.
- Current selected variable/global pointer refetch, a larger new allocation,
  free after the last use, no resurrection, and rejection of an actual later
  read through a retired projection.
- Real F48/F47/Expr/F41 recursion; observations cannot substitute for F41.
- Post-F38 handle comparison, source block-switch stopping order and conditional
  displacement skipping; no continuation beyond a source stop.
- Exact F41 nine-argument Spawn adapter, held body result and reread of body+86
  after the position callback; only F927/F1507 remain external there.
- Warm prepare/commit, cold replay, receipt tampering, re-signed invented
  after-state, revision/ABA checks and cyclic payload preflight.
- Eleven critical frozen 0.31 constituents against hashes read from Git HEAD
  before the audit. The complete old native baseline remains a separate release
  regression check, not a claim made by this small harness.

Two concrete review findings were resolved by the VM owner:

1. An unaligned selected global projection could pass Core21 and create a derived
   expression runner with an empty context, producing engine script errors.
   Unrepresentable globals now remain unused local transport with an explicit
   invalid-read guard; derived contexts are validated before runner creation.
   This is a bounded transport rule, not a claimed original DOS alignment fault.
2. An old expression output buffer could carry unknown provenance while its bytes
   produced a defined scalar. Nonempty old-expression outputs now require all
   bytes known in this conservative composition profile. This can reject unused
   padding that a future precise read-mask adapter could admit. F41 private UI
   windows still retain unknown bytes and their masks normally.

The final source review found no additional concrete evaluation-order mismatch
in the statement dispatcher. Native proof scope and all original DOS instruction
claims are documented by the owning statement/spawn proof packages; this audit
adds independent composition and ownership checks without modifying their code.
