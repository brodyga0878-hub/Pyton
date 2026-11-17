# Actual DOS F578 pair response

The whole original F578 at VA0x4281B8..0x428357 is restored from the uploaded
FIRSTENC.EXE disassembly:114 instructions,416 bytes. Reassembly confirms every
normalised original instruction. The pinned JJFFE source replaced this function;
its mass-based normal/reflection implementation is not used here.

The source sets collision flag0x80 before either branch. Parent/type1 contact
changes each subject velocity to -(signed velocity SAR2), and eligible models
request damage regardless of the collision-enabled switch. Other pairs first
write both velocities to signed32-wrapped(sum) SAR1, even when damage is disabled.
For eligible damage, unsigned16 HP comparison selects a branch once; after the
first F953 the source reloads HP and attacker identity before its second call.

The portable native oracle executes these reviewed DOS instructions through an
ELF64 host stack/register ABI adapter. Pointer data and the stack stay below2GiB;
argument slots widen from4 to8 bytes. Source object fields retain original sizes.
DOS CRT abs is separately pinned by its original bytes. F953 is an ordered full
before/after observation boundary, not execution of damage or world effects.

The bank contains288 independent raw cases, repeated in three fresh processes
and reversed order, plus32 actual native state-retaining continuations (each
launched with the preceding native output). The complete338-byte subject,
338-byte collider, globals and F953 arguments/context are compared. Response
patches are explicit input bytes; Python never computes expected collision math.
The reviewed wrapper checks context/output canaries and exact output length.

The generator default uses only these captured proof/source files; private EXE,
ASM and data paths are read only with --refresh-original-proof. A copied-proof
replay with deliberately absent originals reproduced the fixture byte for byte.

Godot test result:3414 checks,0 failures;320 native controls,155 observed F953
boundaries,32 continuations and cold JSON reloads. This is not a full F575/F569
pipeline, collision geometry provider, damage engine or Main/Android proof.
