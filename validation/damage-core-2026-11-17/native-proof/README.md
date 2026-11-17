# Whole original damage and shared RNG oracle

The executable research adapter runs whole original DOS F953, F34/F35,
F144/F148, F1538, F1530 and F922. All 241 instructions in these eight complete
procedures are independently assembled as IA32 and compared with the pinned
uploaded executable before host adaptation. Captured source, disassembly,
symbol addresses, complete-procedure hashes and callback words replay without
the private original files.

F34 writes the real 71-word event table and calls an explicit F48 boundary;
F35 rereads register12 after all three dispatches. The source F953 module loop
rereads its signed module count, flags and body state. Whole F148 executes its
separate fixed21-module loop. Whole F144 executes the original null/non-null
table dispatch using captured DOS event2/event11 words from all21 tables.
Only nonnull handlers request an external result. Each table's original
pointer, file offset, exact48-byte DOS span and hash are recorded.

F1530 and F922 bind directly to the same Root+0x24/+0x28 bytes. There is no
second RNG owner. F922 retains the original low32-bit IMUL before SHR16.
Whole F1538 reads supplied immutable68-byte model descriptors; the source
physical-resource word at+0x38 determines eligibility. Its actual-read
profile covers original initialized-object model indices0..148.

## Explicit external boundaries

F48, nonnull F144_handler, F1907 audio, F942 fatal response and F952 equipment
effects require ordered matching observations. No handler receives an
implicit successful or unchanged response. Native discovery stops at the
next unresolved request; the generator authors an explicit return and raw
owner effects before rerunning from the original inputs.

Every resolved callback records full native before/after snapshots of body,
Root, flags, event registers, module entries and module count. Model resources
remain immutable and their bytes/guards are checked. Callback effects can
change subsequent source reads, including event register12, body identity,
class, model, shields/hull, sound-dependent hull-quarter reloads, dynamic
module count/flags and the shared RNG words. Fatal/equipment return words
0, FFFFFFFF, 80000000 and7FFFFFFF are forwarded by the original F953 branches.

For F144_handler event2, optional `payload_after_u32:[action,value]` writes the
actual two words on F148's reusable stack packet. Later handlers reread those
mutated words. Event11 exposes its defined fields and normalized sole body
owner; writes to event11 stack locals and uninitialized packet padding remain
outside this boundary profile. No original handler, audio, explosion or
equipment implementation is claimed by these explicit responses.

## Corpus and reproduction

The fixture has309 operation-tagged cases:261 F953 calls,16 F1530 calls and32
F922 calls. It contains1,135 full native callback observations,21 individual
original module-table dispatch probes,63 dependent Root steps and the eight
F922 bound words0/1/2/FFFF/10000/7FFFFFFF/80000000/FFFFFFFF. Exact shield and
hull equalities, signed filters, empty/negative module limits, mutable body
and flags, both source loops and mutable F148 packets are included.

All completed cases run in three fresh native processes and again in reverse
packet order. Root/event/module/body state is compared in full. Boundary
canaries and immutable descriptor guards must remain unchanged. Expected
arithmetic is never calculated in Python; compression, deduplication and byte
patch transport do not replace original calculations.

From the project directory, Python3 and GNU as/ld/objdump are sufficient:

```sh
python tools/rebuild_source_damage_native.py
```

The default replay uses these captured proof files and repository resources.
It never opens the default EXE/ASM/data paths. A copied proof directory with
all three paths explicitly absent reproduced the exact41,421,515-byte fixture
without changing its four captured proof files. Independent original reproof
also reproduced those files and the fixture byte for byte:

```sh
python tools/rebuild_source_damage_native.py --reprove-original \
  --exe /path/FIRSTENC.EXE --asm /path/ffe.asm --data /path/ffedat.asm
```

See `rebuild-verification.json` for final hashes, measured counts and limits.
The runtime passed3,506 damage and305 RNG checks against the native corpus.

## Native composition API

`verify(PROOF)` returns `(metadata, source, kernel_assembly)`. Assemble the
kernel using `as --64`, then link with `ld`. `packet(rawrow,scripts=None)`
produces a65536-byte input. `decode(output,rawrow)` reads one variable-length
output and returns status0 for completion or1 for an unresolved explicit
boundary, together with actual native state, requests and observations.
Concatenated inputs produce concatenated length-prefixed outputs; the byte
length is the uint32 at output offset4.

The raw row contains operation (`damage`, `rng1530` or `rng922`),
body_before_hex, context_before, damage_s32, attacker_u32 and bound_s32.
Context uses root_hex(16384bytes), flags_hex(115), event_registers_hex(284),
module_entries_hex(168), module_count_s32 and model_descriptors_hex keyed by
canonical model strings with68-byte values. Callback scripts specify kind,
canonical args, return_u32 and explicit patches `{owner,offset_u32,bytes_hex}`.
Optional event2 payload_after_u32 carries the local packet effect.

F48 args are `[2,0,register]`; F144_handler args are
`[module,event,payload0,payload1]`, with event11 normalized to
`[module,11,1,body_index]` and event2 initially `[module,2,23,0]`.
F1907 args are sample and signed log-volume. F942 args are current body index
and attacker word; F952 has current body index. Source-order traces include
the actual helpers and dispatcher even when a null entry makes no request.

The JSON fixture stores lossless SHA256-keyed zlib buffers, including all
native callback snapshots. `hydrate_buffer`, `hydrate_context` and
`raw_row(fixture,row)` reconstruct the native packet inputs and explicit
scripts while validating buffer lengths and hashes. This codec changes no
game arithmetic. The transport supports64 callbacks,10 raw patches per
callback and32 bytes per patch; those research transport bounds do not claim
every possible original callback behavior has been ported.

Live Main, Android performance, full object scanning and the original
destruction/module callback implementations are outside this proof.
