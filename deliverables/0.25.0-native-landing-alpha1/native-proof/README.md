# Original natural contact and parked-state witnesses

From the repository root, Python 3 and GNU `as`, `ld`, `nm`, `objdump` suffice:

```sh
python validation/contact-lifecycle-2026-11-15/native-proof/validate_source_contact_lifecycle_native.py --replay
python validation/contact-lifecycle-2026-11-15/native-proof/rebuild_source_contact_lifecycle_native.py --work /tmp/contact-lifecycle-reproduce
```

The second command uses the archived assembly, reproduces the fixture and summary byte for byte, and does not need the game executable. It changes no previous fixture or proof. Work products remain under the explicitly supplied temporary directory. No generated executable belongs in the source archive.

To independently regenerate the assembly and repeat the original DOS instruction comparisons, additionally supply the pinned originals:

```sh
python validation/contact-lifecycle-2026-11-15/native-proof/rebuild_source_contact_lifecycle_native.py \
  --original-source /workspace/ffe-upstream/jjffe/ffe.asm \
  --data-source /workspace/ffe-upstream/jjffe/ffedat.asm \
  --executable /workspace/ffe-original/FIRSTENC.EXE \
  --work /tmp/contact-lifecycle-original
```

Dependencies already present in the source archive:

- `tools/rebuild_source_natural_contact_native.py`, its `rebuild_source_surface_contact_native.py`, `rebuild_ground_surface_native.py` and original helper-proof dependencies;
- `recovered-history/ground_harness/tools/{build_terrain_query_reference,native_reference}.py`;
- `validation/footprint-2026-11-14/native-proof/{rebuild_source_footprint_native.py,footprint-observed-kernel.s}`;
- the unchanged four fixtures `source_natural_contact_native.json`, `source_contact_field_native.json`, `source_footprint_native.json`, `source_contact_frame_native.json` under `tests/fixtures`;
- this directory's archived `lifecycle-observed-kernel.s`, `excluded-native.s`, instruction proof and generator. The ordinary archived replay does not require the earlier native executables or their temporary build directories.

## Exact bounded scope

The 402 witnesses comprise 247 full original F574 actor calls, 76 explicit F574 requeries of actual corrected native bodies/history, 76 separately restored F1030 parked updates, and three separately intercepted F1047 launch-entry prefixes. Actors cover natural solid models 117–133, actual positive Eagle24/Cobra38/Shuttle15 bounds initialized by original F1533, ordinary near-boundary samples, canonical outer gates, true broadphase skips and actual Cobra/Shuttle child contacts. Every bank executes in three fresh native processes with forward/reverse repeat comparisons and body/parent/relative/output canaries. Expected contact arithmetic, terrain heights, offsets and corrections are never calculated in Python.

F574 actually sets collision_enabled=0. These calls therefore prove the disabled-damage query/correction path, not damage-enabled full F569/F570 flight. Complete original F575 and bounded natural F576/F579/F582/F581/F1876 instructions execute. Unsupported city/general VM, station and damage functions remain explicit abort traps. F1876 leaf triangles and history-write freshness use the unchanged existing native observers.

On an actual source flag40 natural acceptance, the exact F1021/JUMP4228 branch executes after the full contact call. Original F1042 clears integer velocity dwords 8C/90/94; target/rate words B0/B2/B6/B8/BA; and DATA8918. Nonzero input fractions EC/EE/F0 remain untouched. The native branch records parent, sets F8=FF and state E8=32hex and issues the actual two observed UI F48 requests. F48 and optional sound F1910 are request observers; their UI/audio engines are not executed. Source globals inside DATA8804 use their actual structure aliases, including graphics level at +10hex, player index +C0hex, sound flags +C6hex, current-body pointer +C8hex, state +E8hex, launch dword +F0hex and F8 byte. DATA8918 at +1B8hex is captured separately beyond the exposed 256-byte root.

Natural state32 dispatches to original F1030, which is literal RET. It does not requery contact. The separate cold controls restore captured bytes and rebind the isolated native body/parent references, then execute F1030. This proves the bounded raw-state update; it does not prove the original save format, complete F1009 clock/gear update, Android process restoration or phone physics policy.

The explicit corrected-body F574 bank is deliberately different from state32's RET update: 75 of 76 corrected bodies return F576−1, one still contacts. Source no-hit after a source landing correction is therefore genuine source behavior, not evidence that the correction must be discarded or the contact forced true.

Three actual F1047 entry prefixes observe UI148(14,0), write state34/F8FF/F0=1, then stop immediately before F1119. F1049 and subsequent reset/control/flight routines are unexecuted. No complete takeoff or free-flight claim follows from these entry witnesses.

## Instruction provenance and ABI

All 19 full procedures in `instruction-proofs.json` compare equal to the uploaded DOS executable: 1,409 instructions / 4,202 bytes. F1021 and F1047 are fully statically compared; only the explicitly described branch/prefix executes. Other unchanged natural/query helpers and resources retain their previous immutable proof provenance. Additional F1021/F1042 entry addresses are anchored by unique original opcode prefixes before the complete comparison, avoiding unjustified large JJFFE `Pos` deltas.

The research host harness uses low-address x86-64 stack slots while retaining original signed32/Q31 and signed64 operands. Pointer callback words are loaded as DWORDs before CALL; original 32-bit frame-argument slots widen to eight-byte host stack slots, original local integer operands remain their source width, and the inherited widened terrain frames remain unchanged. Preserving observation wrappers do not replace source arithmetic. The archived native assembly and abort adapters make all adaptations reviewable.

F579 passes the actual ship threshold unchanged except the original vector-scale shift; DOS F581 uses its actual SAR16 threshold comparison. The full F575 response subsequently uses the full initialized inner bound minus selected previous altitude. These are observed original instructions. This proof does not infer a design intent, reinterpret the source pivot as the visible gear minimum, change signs or units, add an epsilon, or certify rendered surface identity.
