# Whole original destruction and cargo kernel

This proof executes complete original DOS F942/F926/F927/F928/F924/F144,
F1533/F1538/F1495/F1341, F1530/F922, F1675/F1914/F1521 and F1514.
All 872 instructions of these 16 complete procedures were independently
assembled as IA32 and compared with the uploaded original executable before
the documented ELF64 ABI adaptation. The C support transports bytes, binds
low-address owners, observes defined callbacks and checks guards; it does not
calculate expected gameplay, model initialization, matrix, RNG or displacement.

The runtime parity suite passes **2486 checks, 0 failures** against **170** native
cases. The native cases include 154 actual explosion matrices, 192 F926
attempts, 57 successful cargo153 allocations and position updates, 399 explicit
provider responses, six actual low-word/signed64 displacement edge controls,
and twelve dependent calls carrying preceding native bank/Root/module state.

The main generator repeats cases in fresh native processes and reverse order.
A separate complete cohort replay also places all 170 packets in one native
process, repeats that cohort in three fresh processes, then reverses it: every
raw output and existing expected owner snapshot is byte-identical. See
`rebuild-verification.json` for the measured hashes and output size.

## Replay

From the project root, GNU assembler/linker, GCC, Python3 and objdump are used:

```sh
python3 tools/rebuild_source_destruction_native.py
```

Default replay never reads the private FIRSTENC.EXE/ffe.asm/ffedat.asm. A copied
proof directory with all three original paths absent reproduced the exact
fixture and all five captured source/proof/host files. A separate full original
reproof also reproduced those bytes, using:

```sh
python3 tools/rebuild_source_destruction_native.py --refresh-original-proof \
  --exe /path/FIRSTENC.EXE --asm /path/ffe.asm --data /path/ffedat.asm
```

## Owners and pointer policy

The exact public context is `{root, bank, module_entries, module_count_s32,
model_resources}`. Root is 16384 bytes, bank is 38986 bytes (116-byte header
including the sole flags bank, then 115 records of 338 bytes), and the module
flag/private window is 168 bytes. The supported inclusive module limit is a
signed word up to20. The Root already owns shared RNG words at0x24/0x28,
transient count at0x70, player index at0xc0, player reference at0xc8, money at
0x114 and rank counter at0x19c. No second persistent counter/RNG/flags owner
is created.

Physical body slot and record+0x86 logical index are distinct. Source pointers
continue to address the original physical record even when allocation reuses
that slot or a callback changes its logical index. F924 retains its captured
index across callbacks and clears that flag; it does not erase the record.

Root+0xc8 transports a canonical logical player slot1..114. Native execution
temporarily rebinds it to the supplied record pointer, and every snapshot
normalizes it back. Zero is null. Opaque unused words remain opaque; runtime
rejects an unbound value if the bounty path actually dereferences the player.
All live owner boundaries have canaries. Input packets, model descriptors,
physical specs and collision probe bytes remain readonly under native checks.

Model resources retain their original historical pointer words as opaque data.
The source lookup table is rebound to low host pointers only during native
execution. Original models0..148 and separately captured cargo153/explosion155
are supported; actual NULL model149 is not invented. All resources share the
single original fifteen-entry drive table. Synthetic mass controls are explicit
raw inputs; they do not claim those masses initialize a natural game object.

## Actual effects and remaining providers

Explosion allocation executes original F928 and F1533 for model155. Its matrix
executes original F1675 using original Sin32/Q31 multiplication. Cargo and
debris execute F926, the distinct reserved-slot F927 allocator (slots>=20),
model153 initialization, shared RNG velocity kicks and original 32-to64 position
addition F1514. Cargo selection uses the exact first32 bytes of D7212. Failed
allocation remains failure; a F926 attempt alone is not reported as creation.

The original F144 null/non-null dispatcher executes; non-null module handler
bodies remain explicit providers. F349 UI messages and F1344 string expansion
also remain explicit providers. Test string providers write declared output
bytes; they are not claimed as original text formatting or localization.
F349 captures only defined fields (message, bounty-presence/value, flags), and
F1344 captures the defined name destination and item. Uninitialized packet
padding and string-variable stack scratch are not fabricated as source data.

These boundaries carry exact before/after contexts and authored returns;
missing or mismatched responses reject the runtime step. This checkpoint does
not establish complete event/handler/UI execution, a live Main world loop,
rendered explosions, a new APK, or physical Android performance.

## Composition API

`verify(proof)` returns `(metadata, source)`; `build(metadata,source,directory)`
returns `(binary_path, host_assembly)`. `packet(row)` serializes one fixed input;
`run(binary,row)` returns `(raw_output,decoded_output)`, and `decode(raw,row)`
validates captured owners/requests. `fill_scripts(binary,row)` measures pending
requests and supplies explicitly authored test providers. `raw_row(row,buffers)`
hydrates lossless fixture buffers and verifies their byte count/SHA256.

Runtime `SourceDestruction.execute(context,physical_slot,attacker,observations)`
returns a private `context_after`, source zero return and measured call order.
An observation is `{kind,args,before:context,after:context,return_u32}`. The
public JSON codecs accept exact hex buffers; native pointers are never saved.
