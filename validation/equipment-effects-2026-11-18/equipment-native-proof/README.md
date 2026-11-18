# Original equipment and cargo damage instruction oracle

The native fixture executes complete original DOS F933, F943..F952,
F144/F148, F922/F1530 and F1538. Sixteen procedures and 389 instructions
are independently reassembled for IA32 and compared with the uploaded
FIRSTENC.EXE before the reviewed low-address ELF64 ABI adaptation.
Expected equipment, drive, cargo, inventory and RNG results are never
calculated in Python.

F949 contains an embedded 24-byte six-way jump table. Both code ranges are
compared independently; all six original DWORD destinations are captured
and verified separately. The host indirect jump uses scratch r11 solely to
hold the source32-bit target. The source register arithmetic is unchanged.

## Reproduce

From the project directory with Python 3 and GNU as/ld/nm/objdump:

```sh
python3 tools/rebuild_source_equipment_native.py
```

The normal path reads only committed source resources and these captured
proofs. A copied proof directory with all three private original paths
deliberately absent reproduced the exact 2,598,291-byte fixture and left all
five proof captures unchanged. An independent original reproof reproduced
the same fixture and all five captures byte for byte:

```sh
python3 tools/rebuild_source_equipment_native.py --reprove-original \
  --exe /path/FIRSTENC.EXE --asm /path/ffe.asm --data /path/ffedat.asm
```

The original drive-mass table has 15 DWORDs. The equipment-name table has
30 captured DWORDs, although F933 samples only indices 0..28. Runtime
checks compare the complete static tables and their boundary canaries after
each packet. Caller model descriptors and physical 24-byte specifications
are readonly, compared in full after restoring the documented host-only
physical-pointer relocation. All six mutable owner buffers have guards.

## Corpus and state

There are 503 cases, each run in three fresh native processes and again in
reverse order. Twenty-three dependent transitions carry the exact preceding
native Root and target body. The corpus includes:

- Whole F952 player/NPC paths, all F933/F943..951 direct helper entries,
  signed32/unsigned16 inventory arithmetic and source return words.
- Actual hits for all 29 selectable equipment bits. Deterministic raw seeds
  are selected using observed native results, without calculating the
  selected equipment or expected arithmetic in Python.
- The three unreachable rotated bits 29..31, which consume all 29 random
  attempts before failure, and a successful hit on attempt29.
- All38 descending cargo positions, including commodity 30 where the
  selected quantity and Root+0x170 refer to the same WORD: DEC then INC
  cancel exactly. Global totals are not reconstructed or decremented.
- All15 valid player drive indices, opaque negative NPC drive bytes,
  all six weapon mounts, all 21 module registry event2 slots and their
  genuine null/non-null dispatcher behavior.
- Explicit callback changes to selector, drive, module flags, Root fields
  and RNG state; F944's unconditional first broadcast, F943's selector
  reread and optional mutation of the shared F148 action/value packet.

The 276 external observations comprise 212 F349 UI calls and 64 non-null
F144_handler calls. F349 captures only the three defined message words
at offsets 0/4/24, not the uninitialized remainder of its 48-byte stack
packet. Handler bodies and UI behavior remain external providers. They
never silently become identity callbacks in the runtime.

All inventory, cargo, weapon-mount and random words alias the same 16KB
Root. The overlapping cargo/free-space fields deliberately remain raw
source memory. No extra saved seed, cargo sum or fuel count is introduced.

Godot parity: 4,562 checks, 0 failures. See rebuild-verification.json for
measured portability and provenance results. The separate owned-state suite
passed 782 checks over 64 stratified cases including every dependent step. These counts are standalone
functional checks; process repeats and native cases are separate categories.

## API for composition

`verify(proof_dir)` returns `(metadata, source, kernel_assembly, resources)`.
Assemble the single kernel string with `as --64` and link with `ld`.
`packet(row, scripts=None)` produces one 131072-byte input. `decode(output,
row)` validates the variable output (size at header+4) and returns actual
expected state, ordered observations and an optional next typed request.
Independent packets can be concatenated in one native process.

`raw_row(fixture, pooled_row)` hydrates one fixture row and its authored
callback scripts. `hydrate_buffer` verifies decoded byte count and SHA256;
`hydrate_context` restores the seven-field context. The context is the
previous six-field damage context plus readonly `physical_specs` keyed by
canonical model strings. Direct helper operations use an `args` array:
F944 `[message_u32, parameter_u32]`, F946 `[amount_s32]`, F951 `[index_s32]`;
other operations have no extra arguments. Actual model reads are bounded
to the supported 0..148 catalog, while an unused NPC model word is opaque.

This verifies bounded source kernels and exact explicit continuations.
It does not implement actual UI/module handler bodies, the F942 debris
engine, live Main integration, a new APK or physical Android performance.
