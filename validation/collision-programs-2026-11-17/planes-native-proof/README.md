# Original DOS F583 packed planes

`FIRSTENC.EXE` SHA256:
`d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72`.
Whole F583 at `0x428E84` and F1656 at `0x4599B4` are independently
reassembled and compared with **171 original instructions**. The original
Watcom abs bytes are also pinned. Native execution uses the documented ELF64
stack/register adapter, low-address buffers and the original signed32 integer
operations. This is not execution of an unchanged IA32 binary.

640 controls cover all 256 plane codes, all four plane/vertex X-sign flag
combinations, signed-byte -128 mirroring, signed32 wrap, masked shifts,
threshold equality, both results and explicit preceding-normal origins. Every
normal/vertex buffer and the entire source context remain unchanged. MOV-only
observations record the normal, delta, truncation shift, comparison distance
and shifted threshold. Three fresh native processes and reversed case order
must match byte for byte. Python creates inputs and compares output; it does
not calculate expected geometry.

Public runtime: `execute(context, plane_u8, threshold_s32)`. Context contains
point_xyz_s32, normals/vertices PackedByteArray, mesh_zoom_s32 and
vector_scale_s32. Optional normal_origin_u32/vertex_origin_u32 default to 0.
The normal read is `origin + (plane >> 1)*6 - 6`. Missing prefixes or referenced
vertices fail closed. F583 itself does not consume or advance a program cursor.

Portable repeat:

```sh
python3 tools/rebuild_source_collision_planes_native.py --output /tmp/planes.json \
  --exe /absent/FIRSTENC.EXE --asm /absent/ffe.asm --data /absent/ffedat.asm
```

`--proof-dir` supports a copied proof directory. `--reprove-original` checks
the original uploaded EXE and assembly again. The included portable verification
records an exact fixture repeat without any original files. F582 decoding,
F580 recursion, F576 contact, Main and physical Android remain outside this
standalone plane module's scope.
