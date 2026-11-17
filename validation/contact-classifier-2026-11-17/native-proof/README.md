# Whole DOS F575 classifier controls

The captured original source executes whole F575 with real F577 sphere,
restored DOS F578 pair response, F571/basis/projection/vector arithmetic,
and original F1538 descriptor lookups. All 149 original descriptors and their
24-byte physical-specification prefixes are captured from the exact DOS EXE.
F576 general geometry/VM and F953 damage effects are explicit typed matched
observations. This is not the complete collision geometry/VM, Main or Android.

The 392 controls include 32 dependent native steps. Three fresh executions of
every input and reversed whole-bank order produce identical output. Complete
338-byte subject/collider records, caller absolute vector, signed local vector,
all 13 external collision/player words and source callback order are retained.
Boundary response scripts are inputs, never Python-calculated expected physics.
Identity byte86 is a stable logical bank identity in these controls. Observed
identity changes lie outside this normalised-reference domain. F576 return0
with classification kind2 is excluded because only the F577 path initialises
the distance-squared local used by the kind2 continuation.

Before host adaptation, every captured procedure is independently assembled
as32-bit code and compared with the whole original DOS instruction sequence.
Default portable replay repeats that static comparison against the captured
normalised instruction hashes. Host execution uses reviewed ELF64 expanded
cdecl argument slots, low-address data/stack and contiguous F577 value arguments;
it does not execute an unchanged IA32 binary. DOS F577's parent+138 radius and
original DOS F578 (not the later JJFFE rewrite) are restored before proof.

Portable command, with --exe/--asm/--data deliberately absent:

    python3 tools/rebuild_source_contact_classifier_native.py --output /tmp/classifier.json --exe /missing/FIRSTENC.EXE --asm /missing/ffe.asm --data /missing/ffedat.asm

A private copy supplied through --proof-dir also reproduces the fixture exactly.
--reprove-original regenerates all whole-instruction proofs against the pinned
private originals. The fixture SHA and actual counts are in reproduction.json.
