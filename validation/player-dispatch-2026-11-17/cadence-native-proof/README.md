# DOS object callback cadence controls

This bank executes the whole original F149 and F144 procedures after an
independent comparison of their source instructions with the uploaded DOS
`FIRSTENC.EXE` (SHA256
`d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72`).

F149 scans stable slots 114 down to 1. For bank flags mask `0x01`, it decrements
the raw byte at object `+0x8B`, wrapping modulo 256. Only an old value of
zero reloads it from `+0x8A` and calls F144 with object type `+0x87`, event 5
and the exact raw clock/context pointer. F144 selects the registered event
handler; the null handler is a distinct observed path. The JJFFE added
laser-invulnerability pass is absent from this DOS procedure.

The host has no IA32 execution support. The existing reviewed ELF64 adapter
widens stack slots and saved registers while retaining the source's 32-bit
arithmetic and 338-byte raw records. F144's two pointer-table strides are
widened from 4 to 8 bytes only for host code pointers. A register/flags
preserving call-boundary observer records every F144 attempt, then executes
the original F144 instruction body.

Callback function bodies are explicit event/context recorders. Optional
declared byte mutations exercise source-order effects on later indexed
objects. They are witnesses for a callback boundary, not implementations of
the original AI, physics or other handlers. The default event-5 presence
list `[1, 3, 5, 7, 11, 17]` is separately read from the original 21-selector
callback table; the fixture also uses explicitly supplied presence maps.

There are 265 native cases, including 32 dependent steps whose next raw
input comes from the preceding actual native output. Three fresh native
processes and reversed case order match. Guards, the 115 flags, all
unprovided records and raw context words are checked. F149's global bank
pointer write is observed; direct F144 preserves the explicitly seeded
nonbank sentinel instead.

Reproduce from a complete project without private original files:

```sh
python3 tools/rebuild_source_object_cadence_native.py \
  --exe /nonexistent --source /nonexistent --data /nonexistent \
  --output /tmp/source-object-cadence-replay.json
```

Compare that file byte-for-byte with
`tests/fixtures/source_object_cadence_native.json`. The default uses the
included source/disassembly proof and reassembles its 32-bit instruction
forms before running the native controls. `--refresh-original-proof`
explicitly verifies a fresh copy of the pinned private originals.

No complete world scheduler, original callback effect graph, live Main
flight, Android execution or long-range-route completion is claimed.
