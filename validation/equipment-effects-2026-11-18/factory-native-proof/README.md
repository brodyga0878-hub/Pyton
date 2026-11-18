# Original cargo153 and explosion155 factory resources

This adds exactly two selected original model-table entries. Original slot149
is a null pointer. Other entries above148 are not inferred to be absent: the
largest selected index155 is not claimed as the original table length.

The original executable supplies the actual index→pointer table words,
68-byte descriptors, optional24-byte physical specification, collision-program
first byte, and the15-entry drive mass table. `resource-spans.json` preserves
each exact source range and its SHA256. Default replay reconstructs the exact
`data/ffe_effect_factory.json` from those spans without opening the executable.
Model153 has a physical record and nonempty collision program; model155 has
no physical record and its collision program begins with zero.

## Original instructions and runtime adapter

Four whole original procedures F1533/F1538/F1495/F1341,214 instructions, are
independently reassembled for IA32 and compared with the captured original
instruction bytes. The host research program uses the documented ELF64 ABI
adapter from the established factory oracle, with a156-slot low-address
descriptor table to admit the selected indices. It does not execute an
unchanged IA32 binary and is not an Android emulator.

F1533's nonzero model token is used only for the zero/nonzero branch, the
store at body+0x82, and F1538's descriptor selection. Immediately after the
lookup ESI becomes the descriptor pointer. The captured source's exact six
token-related instructions before that replacement are checked by the tool.
The new Godot module therefore calls the unchanged descriptor-parametric
factory with token1 and the exact selected resource, then writes the actual
selected model token at+0x82. Whole original F1533 controls use the true
indices153/155 and compare all338 output bytes. The existing0..148 factory
catalog, implementation and default behavior remain unchanged.

## Controls and replay

There are616 native cases, each run in three fresh processes and in reverse
order. Both selected models preserve all256 type87 bytes; copy/in-place
identity, destination-reference endpoints and raw clock words are exercised.
Twenty-four dependent cases carry the complete previous original output.
All source/resource buffers and boundary canaries remain unchanged.

```sh
python3 tools/rebuild_source_effect_factory_native.py
godot --headless --path . --script res://tests/test_source_effect_factory.gd
```

The default command requires only the archived text proofs, project
resources, Python3 and GNU as/ld/objdump. A copied-proof replay with all
original EXE/ASM/data paths deliberately absent reproduced the exact
fixture and left all five proof inputs unchanged. An independent
`--reprove-original` invocation also reproduced every captured file and the
same fixture. `rebuild-verification.json` records the measured identities.

This is object initialization with selected additional source resources.
It does not claim bank allocation, live explosion/debris orchestration,
source effect rendering, all remaining models, Main integration, a new APK
or a physical Android/FPS result.

For composition, `verify(proof_dir)` returns `(info,captured,resources)`;
`assembly(captured)`, `packet(row)` and `decode(raw,row)` expose the
reviewed provided-resource transport. Each input is800 bytes, output848.
