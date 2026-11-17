# Original DOS player mode dispatcher

This proof covers whole F1008 (72 instructions/305 bytes), F1009 (38/120)
and F1010 (19/64): 129 original instructions and 489 bytes. The real DOS
control/post table contains 29 pairs, then a zero pair. Positive odd phases
share the preceding pair through the original signed-byte arithmetic shift.
The typed runtime admits phases 0..57 for indirect calls; it does not invent
behavior for the original null or negative table indices.

The native oracle runs the archived instructions through the established
64-bit cdecl adapter. Raw integer arithmetic remains 32-bit. The table keeps
32-bit pointer slots and the original scale of eight; low-address host stubs
observe selected handlers. Body pointers and the original F1097 argument
words are checked. Each observer saves all general registers and flags,
records the complete before state, applies supplied raw byte responses, and
records the complete after state. Subsequent original instructions read that
returned state. No Python implementation computes expected game arithmetic.

All 338 body bytes, all 16,384 raw root-window bytes, and the three external
words are compared. This window is not a claim to the entire GameRoot.
DATA8868/8869 are root E0/E4, DATA8870 is E8, DATA8872 is EA. DATA9155 and
the two action words remain external. Root C8/CC are preserved opaque raw
words here; these procedures neither dereference nor replace them with host
pointers. Callback bodies are observed boundaries, not implementations.

The fixture has 568 cases: 264 housekeeping, 164 control, and 140 post calls.
It includes every phase 0..57, 40 callback-response cases, 32 consecutive
native steps, raw clock borrow/wrap, timer/threshold edges, and three fresh
process replays plus reversed-order replay. Both state guards must remain
unchanged. Full root hashes are computed from native output before sparse
storage. The fixture pins the source, proof and all imported helper files.

Portable replay needs Python 3 and GNU as/ld/objdump, but no installed game:

```sh
python3 tools/rebuild_source_player_mode_native.py
```

Fresh DOS verification additionally needs the pinned FIRSTENC.EXE, ffe.asm,
and ffedat.asm (or explicit --exe/--asm/--data paths):

```sh
python3 tools/rebuild_source_player_mode_native.py --refresh-original-proof
```

Portable replay was also run with all three original paths pointing to
missing files. Its generated fixture matched SHA-256
`5f13bed8a6664f64636200b098d8485e95fad9c97c2855baab517ab8a8ebad7e`.

No Main routing, renderer, complete player handler set or world scheduler is
claimed by this standalone dispatcher proof.
