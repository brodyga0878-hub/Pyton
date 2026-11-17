# Whole F581 terrain instruction oracle

The fixture executes whole original DOS F581, real F1876, integer vector,
matrix, length and terrain workers, original height tables/maps and authored
feature streams. No expected geometry or terrain result is calculated in
Python. F581 returns its actual hit word, next payload pointer, twelve
collision words and two persistent query words. F1876 arguments, depth and
vertex count are observed without replacing the calculation.

Before adaptation, all 8,978 instructions of 55 complete source procedures
are independently assembled for IA32 and compared with the uploaded DOS
executable. The archive contains the selected source, original disassembly,
symbol addresses and normalized instruction hashes. F1466's indirect
DATA_007738 callback word is checked against the original F1502 address.
The original DOS integer abs byte sequence is checked separately.

The ELF64 research adapter widens only stack argument slots and explicitly
reviewed scratch frames. It retains source 32-bit arithmetic and four-byte
data pointers, using low-address buffers and stack. Original SetJmp's initial
return is zero. LongJmp allocation failure and unexercised render/helper paths
abort the native process. The adapter does not claim those paths execute.

## Reproduce

From the project directory, the default command requires Python 3, GNU as,
ld, nm and objdump, and uses these archived text proofs and source resources:

```sh
python tools/rebuild_source_collision_terrain_native.py
```

The default path never opens FIRSTENC.EXE, ffe.asm or ffedat.asm. An independent
test with a copied proof directory and all three original paths absent
reproduced the exact 1,619,183-byte fixture without changing any proof file.
To check the uploaded original again, supply the private paths explicitly:

```sh
python tools/rebuild_source_collision_terrain_native.py --reprove-original \
  --exe /path/FIRSTENC.EXE --asm /path/ffe.asm --data /path/ffedat.asm
```

The original reproof was also repeated independently: all five captured
proof files and the resulting fixture were byte-identical. See
`rebuild-verification.json` for hashes and measured counts.

## Corpus and state

There are 349 cases: 317 base cases, repeated in reverse order, and 32
dependent calls carrying the preceding native collision/query words.
Each base corpus runs in three fresh native processes. There are 167 real
F1876 queries, including 120 negative recorded results. Actual queries cover
all 14 style descriptors, graphics profiles 0..15, original feature lists,
seed endpoints, signed thresholds and interior resource pointers.

All 37 original terrain records are exercised. Authored model116 has equal
inner/outer bounds, so both its original records correctly take source flat
gates. Two clearly labeled raw-input probes override its body bounds and
observer point to execute the unchanged original payloads through F1876.
Those probes do not claim natural model116 object initialization produces
such queries. The other records also retain their authentic native F579
prepared-input probes.

Raw shift cases include INT_MIN/MAX, source CL masking and a nonzero
two-half-word INT_MIN overflow distinguisher. Flat gates preserve arbitrary
full uint32 graphics, pending and recorded words. Query graphics are bounded
to the supported 0..15 profile. All body/program/geometry bytes, unused
1024-byte input tails and boundary canaries are checked after execution.

The persistent source aliases are graphics DATA_008812 at GameRoot+0x10
(DOS VA0x64214c), recorded intersection DATA_009283 (0x6c48e4), and pending
flag DATA_009284 (0x6c48e8). F1876 resets the latter two only when a real
query runs. Depth DATA_009269 and vertex count DATA_009273 are captured
scratch observations; they are not extra persistent runtime owners.

## Native API for composition

`verify(PROOF)` returns `(metadata, source, kernel_assembly, adapter_assembly)`.
Assemble the last two strings separately with `as --64`, then link with `ld`.
`packet(row)` produces one 4096-byte input; `decode(output,row)` accepts one
4608-byte output and checks readonly buffers/canaries. Independent packets
can be concatenated in one native process. Source array capacity is 1024
bytes per program/vertices/normals buffer. Body size is exactly338bytes.

The row's raw operands are body_before_hex, program_hex, offset_u32,
context (point_xyz_s32, normals_hex, vertices_hex, mesh_zoom_s32,
vector_scale_s32 and resource origins), threshold_s32, globals_before and
terrain_state_before. The latter carries graphics_level_u32,
recorded_intersection_raw_s32 and pending_query_flag_u32.

Outputs include hit_s32, next_offset_u32, globals_after,
terrain_state_after, query_count_u32, readonly copies, query_scratch_after
and (for a real query) query_args with seed/style/limit, matrix9, center3
and next feature-list offset. Flat scratch is deliberately sentinel-filled
and must not become public state. The source-order trace is F581/F1822 for
a flat gate and F581/F1876 for an actual query; nested math workers are not
replaced by that trace.

This archive verifies a narrow source kernel and its Godot parity. F575
physical response, full game orchestration, live Main and Android
performance remain outside this proof.
