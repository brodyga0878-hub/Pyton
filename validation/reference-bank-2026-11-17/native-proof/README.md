# DOS reference-bank native controls

The oracle checks **whole F595/F604/F605/F606** and the F590/F1677/F1678
integer helper closure against the pinned uploaded `FIRSTENC.EXE`:
`d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72`.
All **21 procedures** are independently reassembled as x86 and compared by
normalized instructions before the host ABI adaptation. `instruction-proof.json`
records the original virtual addresses, byte spans and hashes; `dos-F*.txt`
contains the original disassembly.

The host does not support IA32 execution. Native research controls use the
reviewed low-address x86-64 cdecl adapter, keeping 32-bit arithmetic, raw record
offsets and instruction order. F1669's scratch reservation expands from eight
to sixteen bytes for its two host-width pops. F595's unsigned spelling of
negative EBP local displacements is normalized before stack-argument widening.
No DOS emulator or this native harness is included in the Android runtime.

## Explicit boundaries

- F1533 executes its actual copy-only branch. Its CRT byte copy is a host adapter;
  model/equipment initialization branches trap.
- F866 is a **call-boundary observer**, not the orbital implementation. It checks
  that F595 supplied a separate stack COPY, records the requested future raw
  tick/day, and deliberately changes only that COPY's position low DWORDs.
- DOS F595 reads the original EBX position again after that call. Its ordinary
  natural-parent velocity result is therefore zero in this bounded ownership
  contract. JJFFE changes those six loads to the updated COPY. The separate
  sixteen COPY-boundary diagnostics expose that difference without claiming
  proof of JJFFE ephemeris arithmetic.
- F148 observes exact `(11, 0)` requests. The event body, scheduler and other
  effects are not executed or silently substituted.
- F606 executes its real descending bank scan. F590/F1677 update the original
  `+0x25` frame stamp and `+0x26..0x3d` cached global position on candidate
  records. These writes are retained in expected output. Bank flags, unprovided
  slots and canaries remain unchanged.
- Whole F570/contact dispatch, a complete world/object/AI bank, live Main
  integration and a genuinely flown long-range trajectory are not proven here.

## Reproduce

From a complete source project, without the retail EXE or external assembly:

```bash
python3 tools/rebuild_source_reference_bank_native.py --output /tmp/reference-bank-replay.json
python3 validation/reference-bank-2026-11-17/native-proof/validate_source_reference_bank_native.py
```

The generator runs three fresh native processes and all cases in reverse order,
checks the complete raw body/bank/canaries, and writes **444 DOS controls** plus
**16 separate JJFFE COPY-boundary diagnostics**. No Python implementation
produces expected position, velocity, selection, cache or timestamp arithmetic.

For optional original-file reproof, supply the pinned files:

```bash
python3 tools/rebuild_source_reference_bank_native.py --reprove-original \
  --source /workspace/ffe-upstream/jjffe/ffe.asm \
  --data /workspace/ffe-upstream/jjffe/ffedat.asm \
  --exe /workspace/ffe-original/FIRSTENC.EXE
```
