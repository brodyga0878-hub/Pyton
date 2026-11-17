# Whole DOS F580 nested-model transform

Source: FIRSTENC.EXE SHA256
`d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72`.
F580 is `0x428430..0x4285EC`, 152 executable instructions and a separately
verified embedded table of six DWORD jump targets at `0x428539` (24 bytes).
Reassembly matches every instruction and exact table bytes. The raw byte
variants selected by GAS are equivalent MOV encodings; these differences
are checked separately and do not replace the captured DOS byte identity.

The portable native oracle executes the captured instructions with a reviewed
ELF64 cdecl stack/register adapter. It retains 32-bit wrapped arithmetic and
original DWORD table indexing; host indirect jump reads that DWORD into EAX
before jumping through RAX. F1538 is a supplied-descriptor boundary with its
model argument checked. F582 records the exact transformed context, threshold,
program/body identities and supplied signed-byte return; its program is not
executed by this isolated transform oracle. This is not raw IA32 execution,
an Android emulator, complete geometry, Main integration or an APK proof.

416 controls comprise 384 directed/random contexts and 32 genuinely dependent
native calls. Every row is repeated in three fresh native processes and reversed
order. All six permutations, flips, signed negative vertex records retained by
explicit buffer origins, masked shifts, overflow, descriptor zoom and caller
threshold are covered. Every raw body/model/vertex/program buffer is checked
unchanged and surrounded by canaries; context/descriptor pointer slots are
normalised and compared to their independently initialised values.

`source_collision_transform.gd` exposes pure `prepare_nested` and
`resume_nested`. The program owner executes recursive F582 itself. Axis low-bit
codes6/7 would use an uninitialised destination in the original, so they reject.
Out-of-range packed vertices reject instead of reading outside retained data.
No expected coordinate arithmetic is calculated in Python.

Portable replay:

```sh
python3 tools/rebuild_source_collision_transform_native.py --proof-dir validation/collision-programs-2026-11-17/transform-native-proof --output /tmp/source-collision-transform-replayed.json --exe /absent/FIRSTENC.EXE --asm /absent/ffe.asm --data /absent/ffedat.asm
```

This replay was executed from a copied proof directory with all three private
paths absent and reproduced the committed fixture byte for byte.
