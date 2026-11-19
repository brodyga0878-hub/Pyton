# Original DOS mission task lifecycle oracle

This checkpoint executes the complete uploaded DOS F38, F47, F52 and F53:
**4 bodies / 177 instructions**. Every original instruction is independently
reassembled and normalized against captured executable bytes before the ELF64
ABI adaptation. Call sites and the F32 function-word push independently anchor
the four entry points. The actual task arena is 0x60bf50 and module table is
0x48e0f8.

## Uploaded DOS variants

F38 compares the packed task handle and then performs cancellation. It has no
state 1..4 admission guard; the later JJFFE listing added that guard. Therefore
matching inactive or other state values are not universally source no-ops.
Stale handles are no-ops. The descriptor is reloaded after F33.

F47 gates on state 1 and directly loads the clause pointer at block+8+4*index.
It has no declared-count check; later JJFFE added one. A pointer beyond the
block's declared clause count can still be read when its address is valid.
The bounded portable profile validates the resource span, limits the transported
index to 0..16383, and does not substitute a count-based no-op.

F53 resumes at clause 1 after a true predicate (xor index, then the common
increment), reloads the current block after callbacks, and preserves F41 call
ordering even when F31 changed the state. F47 overwrites callback-mutated state
with 2 on a true predicate and resets to 1 only if F41 leaves it at 2.

## Transport and continuation contract

Five persistent context fields contain the 5400-byte arena, immutable program,
original program base, readonly module reference map and F52 caller cursor.
Arena +8/+16/+28 fields use source pointer provenance; +32 variable IDs remain
opaque to these four bodies. Original resource bytes are never rewritten.
Five reviewed pointer-load sites translate resource references into a fixed
host program window. Two controls preserve untouched opaque words numerically
equal to host program data at 0x60000008.

F31/F37/F41/F51/F33 are explicit typed continuations, with exact before/after
contexts, arguments and returns. F52's F31 caller cursor and F37 callee cursor
are distinct; F47/F53 use private local cursors. A callback cannot mutate an
inaccessible stack value. F51 returns a physical slot 0..149, or FFFFFFFF for
NULL. F52 returns a packed handle; handle zero after generation wrap is valid.
Unconsumed void EAX values are normalized to zero.

There are 260 normal native cases, 838 typed boundaries and all 105 actual
module initialization streams. Controls include reentrancy and block rereads,
registration order, F47 count-boundary pointer reads, F52 two-cursor stores,
F53 rescan order, and 12 dependent cancellation/generation transitions through
FFFF to zero. Three fresh process cohorts and reversed order are byte exact.
The independent portable runtime passes 3831 checks with no failures.

A full-arena F52 NULL allocation runs as a separate original SIGSEGV domain;
no successful source after-state is claimed. Null caller task plus nonzero
arguments is an explicitly unsupported bounded transport profile, rather than
a universal original null-task fault: a literal F31 can avoid task dereference.
A null caller cursor with arguments is a distinct dereference hazard. Zero
arguments permit both null caller pointers.

## Reproduction

```sh
python3 tools/rebuild_source_mission_task_native.py
python3 tools/rebuild_source_mission_task_native.py --reprove-original \
  --exe /path/FIRSTENC.EXE --asm /path/ffe.asm --data /path/ffedat.asm
```

A copied proof with EXE/ASM/data paths absent reproduces the fixture and all
five generated captures byte for byte. Independent reproof from the pinned
original files does the same. See rebuild-verification.json for sealed hashes.
This is an offline ELF64 instruction oracle with a reviewed ABI bridge, not
unchanged IA32 execution, a complete F41 statement VM, Main integration or a
physical Android test.
