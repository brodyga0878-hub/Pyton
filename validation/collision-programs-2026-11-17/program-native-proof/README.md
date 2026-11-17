# Whole original collision-program controls

The captured F582 and F1822 bodies match the uploaded DOS FIRSTENC.EXE
(d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72):
243 instructions /653 bytes and13 instructions /28 bytes, respectively.
Plane F583/F1656 and nested transform F580 are independently reassembled
and verified using the sibling proof directories before composing this oracle.
F580 performs real coordinate arithmetic and recursively calls the actual F582.
F1538 is a bounded resource-selector adapter returning explicitly supplied full
model descriptors; its original body is not claimed as executed in this harness.
F581 terrain-height collection remains a strict supplied-response boundary.

448 original-instruction controls cover all four record classes, equipment
conditions, inverted masks, real packed-plane predicates, all6 permutations,
reflection bits, F1822 feature-record skipping, real nested F581 call contexts,
and32 dependent native continuations. All448 run in3 clean processes and reverse
order. Complete body, model/context/program input buffers remain unchanged.
Expected AL, output primitive, stream cursor, global words and selected source
call order come from actual native execution, not Python arithmetic.

C0 low-volume records have a source quirk: reaching list zero without volume80
still calls plane0, and can then consume an adjacent byte. Synthetic fixtures
supply two explicit adjacent zero bytes. The checked runtime rejects missing
bytes rather than manufacturing native buffer padding. All actual extracted
programs currently have volume80 for C0, so this synthetic edge does not silently
extend extracted resource spans. Nonterminating or recursive invalid programs
are bounded and rejected without a partial published result.

The reviewed ELF64 host ABI adapts source cdecl stack slots/registers, keeps
source32-bit data arithmetic/four-byte low-address pointer fields, widens only
the two-pop F582 scratch frame to16 bytes, and uses an explicit32-bit load for
the original six-DWORD F580 jump table. It is not raw IA32 executable emulation
or an Android gameplay result. F582's observational ESI cursor is recorded
before its epilogue restores ESI; it is not advertised as an ABI return value.

Portable command (no original executable/source required):

    python3 tools/rebuild_source_collision_program_native.py --output /tmp/program.json

Use --reprove-original with supplied original EXE/ASM/data paths to repeat the
whole-instruction comparison. A copied proof directory and absent private
original arguments reproduced the frozen fixture byte for byte. Runtime tests
report4233 checks,0 failures. Shared proof procedures/counts must not be summed
as distinct original functions across the project. Main and the playable APK
are outside this source-only kernel control.

The separate read-only catalogue audit pins the actual178-model data SHA and
checks985 plane references,158 nested references,37 terrain and57 conditional
records. No packed read exceeds captured source buffers; no nested target is
missing; axis6/7 and negative signed F580 vertex codes do not occur. The graph
is acyclic with maximum depth2. Equipment indices1/2/23 read no later than
byte204 of a338-byte body. All actual C0 records set volume80. These are
structural statements; all37 terrain records still need the F581 boundary.
