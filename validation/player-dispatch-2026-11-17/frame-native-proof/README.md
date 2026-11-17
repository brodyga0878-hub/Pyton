# Original DOS F568/F569/F570 caller controls

The whole original caller and its actual F572/F573 rotations, F1677/F1678
cached global-coordinate helpers and integer closure are independently checked
against the uploaded `FIRSTENC.EXE` before the reviewed ELF64 host adapter.
The static proof covers **23 procedures / 1478 instructions**. The original
executable SHA256 is recorded in `instruction-proof.json`.

The native control bank has **317 cases**, **867 observed F575 calls**, and
**66 actual frame conversions**. It includes a complete descending scan of
all 113 other slots, primary-parent calls, signed cooldown boundaries,
eligibility/type/self filters, hierarchy caches and stale logical references.
Three fresh host runs and a reverse-order run are byte-exact; player and bank
canaries and all bank flags remain intact. Expected caller arithmetic is never
calculated in Python.

F575 is an explicit **mutable observation boundary**. The host wrapper records
the complete subject/collider records, source relative vector and contact
globals, applies the supplied reply script, then lets original F570 continue.
The fixture retains literal before/after observations. The Godot caller must
match every request and consume precisely the recorded trace. These replies
are input observations, not a port or proof of F575 collision classification,
its geometry VM, HP response or other callbacks.

The `collider_ref_u32` value is a logical bank-index token: zero means null,
and 1..114 identifies the corresponding indexed record. The oracle maps it
to its real low-address pointer and back. A stale reference may point at an
unprovided slot because original F570 can return it without dereferencing it.
This token is not presented as the original process pointer bits.

Cache statistics compare only bytes **0x25..0x3d**: **382 candidate records in
110 cases**. A separate **606 complete-record changes** count also includes
the explicit supplied F575 effects and must not be called cache-only writes.

Replay without any private retail/source files:

```bash
python3 tools/rebuild_source_frame_dispatch_native.py \
  --exe /nonexistent --source /nonexistent --data /nonexistent \
  --output /tmp/source-frame-dispatch-native.json
```

The output must equal `tests/fixtures/source_frame_dispatch_native.json`:
SHA256 `1c6a82c85c1ef45f230684ba653d856a64cdf89d93e199e3cce42ab99cf7499d`.
`portable-reproduction.json` records an actual successful run. Optional
`--reprove-original` repeats whole-procedure comparison with the explicitly
pinned DOS EXE and JJFFE assembly available locally.

The fixture's `response_scripts` include only consumed replies. The generator
constructs its fixed-size native packets from the deterministic case source;
unused script slots are not runtime observations. Full world allocation,
F575 execution, player scheduling, Main, Android and a flown long-range route
are outside this control bank.
