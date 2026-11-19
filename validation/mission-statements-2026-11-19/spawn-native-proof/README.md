# Original DOS mission spawn proof

This checkpoint executes whole F39 and F40 with the real F1532 bank lookup,
F1510/F1509/F1338 phase arithmetic and F1675/F1914/F1521 matrix arithmetic:
**nine original bodies, 290 instructions, 674 native cases and 7,340 independent
Godot checks with no failures**.

F39 is a scalar identity function; F40 is a nine-argument object/spawn caller.
The earlier plan's description of them as string functions was incorrect.
Actual F39 starts at 0x412B14 and F40 at 0x412B1C. Both entries are independently
anchored by actual F41 CALL bytes. This checkpoint makes no formatting claim.

The context has Root16384, Root tail6160 and body bank38986. Root+0/+4 bind the
actual clock operands DATA8804/DATA8807. Root+0x580C is the bank pointer, normalized
to1. Root+C8/CC pointers are canonical bank offsets, with0 as NULL. F40 retains
its selected body pointer across callbacks even if Root's player references change.
The body name region is at body+0x124 (hexadecimal), sharing the actual bank bytes.

F39 returns a defined scalar without pointer reinterpretation. F40 returns a
defined nullable logical_bank_offset. Physical body slot0 has offset116 and is
different from NULL. F1532's source arithmetic has no bounds guard; the portable
transport admits parent indices0..114, and does not label other indices as an
original CPU fault.

Only F927 allocation and the actual DOS F1507 position worker remain typed
continuations. Their exact arguments and all three mutable before/after owners
are compared. F927 receives [bank-token1,parent-body-offset,29,arg0] and returns a
canonical body offset or0. Its four-byte stack output is never read by F40; its
uninitialized input is not asserted. An optional explicit four-byte provider
write is captured from the actual stack location. F1507 receives
[selected-body-offset,arg3,sign-extended-low16(arg6),body+BE value] and has no
asserted EAX result. No generic success result substitutes for either world body.

Original F1510 receives the NEW clock words in F40's pushed order: low=Root day,
high=Root tick. It writes eight bytes at body+BA; the caller then adds the low16
phase offset into the high DWORD, modulo32bits. The native closure measures all
carry, multiply, shift and copy results. F1675 writes the first36 body bytes
using the exact readonly65,536-byte original quarter-sine table. The later
JJFFE F1507 implementation is not used.

The corpus covers all256 low-byte F39 values, all256 orientation shift bytes,
scalar and word truncation, signed inclination/eccentricity, parent/result
aliasing, NULL allocation, slot0 and last slot114, clock/rate wrap, ordered
callback changes to the held body, Root, tail and neighboring bodies, and eight
dependent spawns with seven exact whole-owner continuation edges. Three fresh
native process cohorts and reversed replay agree. Expected game arithmetic is
never calculated in Python. Root/bank canaries remain intact.

The final fixture SHA256 is
6ea6d36ae97df54509447ae566b5b9935eca34f6aa474223fd8ffa55d253c379.
A copied-proof replay with deliberately absent EXE/ASM/data paths and an
independent fresh original reproof both reproduced the fixture and all five
generated proof artifacts byte for byte. Rebuild hashes and source pins are in
rebuild-verification.json.

~~~sh
python3 tools/rebuild_source_mission_spawn_native.py \
  --exe /absent/FIRSTENC.EXE --asm /absent/ffe.asm --data /absent/ffedat.asm \
  --proof-dir /tmp/starfrontier-spawn-proof --output /tmp/starfrontier-spawn.json
godot --headless --path . --script tests/test_source_mission_spawn.gd
~~~

The copied proof directory must contain the five generated archived artifacts
before portable regeneration. The original reproof uses --reprove-original.
This is an offline bounded caller/phase/matrix proof, with no full allocator,
original position worker, F41 statement VM, Main or Android gameplay claim.
