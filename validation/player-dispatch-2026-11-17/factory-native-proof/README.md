# Original raw object initializer

The complete DOS F1533/F1538/F1495/F1341 procedures (214 instructions) were
independently compared with the uploaded FIRSTENC.EXE before the documented
64-bit host ABI adaptation. All arithmetic still uses original instruction
widths. The host does not run an IA32 emulator.

The 650 native controls cover all 149 real model descriptors in copy/in-place
contexts, model-zero identity rules, null collision/specification references,
signed radius/exponent boundaries, physical thrust/mass/default-drive branches,
all 256 preserved caller-owned type87 bytes and 32 consecutive native outputs.
Three fresh processes and reverse-order replay produce the same bytes. The
338-byte destination, source body, resources and canaries are checked.

Run portable reproduction without the private original files:

```sh
python3 tools/rebuild_source_object_factory_native.py --exe /nonexistent --asm /nonexistent --data /nonexistent --output /tmp/source-object-factory-native.json
godot --headless --path . --script res://tests/test_source_object_factory.gd
```

The default generator also reassembles the four captured original32-bit
procedures and compares their normalized instructions with the captured DOS
bytes. `--refresh-original-proof` explicitly rechecks the pinned private EXE,
JJFFE assembly and original model/specification bytes.

F1533 initializes a supplied raw caller template. It does not allocate a bank
slot, create the player, set byte87, choose a parent or synthesize a position,
orientation, velocity or time interval. Model-zero in-place preserves its
entire input; model-zero copy clears the destination index exactly as DOS.
Historical descriptor pointer words are logical source references in Godot;
the Android runtime never dereferences native code/data addresses.
