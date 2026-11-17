# Actual native F575 to model programs

32 controls connect three independently verified native kernels:

1. Whole DOS F575 reaches its original F576 boundary.
2. Whole original F576/F579 prepares each child-volume program context.
3. Real F582/F583/F580 executes the actual model's collision program. Its
   native return, primitive and collision globals resume F576. The final
   F576 result then resumes the original F575 continuation.

There are 64 classifier calls, 83 front calls and 51 actual program calls, each
run in three fresh processes and then replayed in reverse order. Python only
serializes these raw results; it does not calculate expected geometry or
collision response. Full body/collider records, vectors, scalar results,
collision-global words and native canaries are preserved and compared.

The source model programs are from `data/ffe_collision_programs.json`.
Initial records come from the independently executed F1533 fixture; identity,
Q31 pose, frame selection and source-space position are explicit authored
test inputs. The selected real model closures fit the declared bounded native
transport (up to 8 nested models, IDs 0..255). This does not restrict the public
runtime's separately validated larger resource catalog.

This cohort executes original non-terrain model programs. It invents no F581
answers. F953 world/damage calls receive explicit matched identity replies;
the authoritative damage engine and object reallocation are not executed.
All kernels use their documented ELF64 ABI adapters, not an unchanged IA32
executable. This is source-core evidence, not a new APK, Main or phone result.

Portable repeat, including an independently copied `--proof-dir`:

```sh
python3 tools/rebuild_source_collision_contact_native.py --output /tmp/contact.json \
  --exe /absent/FIRSTENC.EXE --asm /absent/ffe.asm --data /absent/ffedat.asm
```

The proof and fixture pin every referenced source, captured instruction body,
native adapter, original resource catalog and F1533 seed bank. Supplemental
composition counts remain separate from the primary native fixture totals.
