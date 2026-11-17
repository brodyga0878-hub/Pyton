# Original collision-program resource extraction

`data/ffe_collision_programs.json` contains the exact uploaded DOS collision
resources for primary model-table slots0..148 and their recursive collision
submodel references:178 models in total. This is not a rendering-program export.
All178 programs terminate after a structural walk of original F582 records.

The captured domain has389 records across all four record classes,57 equipment
conditions,37 terrain records,138 backward F576 child records in49 models,
and29 additional nested model indices. The source submodel layout is
`model_index_be16, orientation_u8, vertex_code_u8`, matching F582's actual
stack arguments to F580. All actual child lists avoid the undefined axis6 case.

`original-spans.json` retains993 source byte spans with exact executable
file offsets, logical virtual addresses, bytes and SHA256. Model table base is
VA0x4D0CFC / file0xBA8FC. Descriptor+0x34 selects the collision program;
descriptor+0x00 is the separate render program and is never substituted.

Normal byte captures include the six bytes before the normal origin, because
F583 reads `normal_ptr + (plane_code >> 1) * 6 - 6`. `normals_origin_u32=6`
therefore denotes the original pointer inside that captured byte array.
Some original programs read beyond the span suggested by descriptor counts:
models19,35 and244 retain those exact source-memory read extensions. They are
reported in `packed_read_extensions`; no normals, radii or mesh planes are
invented to repair the uploaded binary's behavior.

`children_hex` contains the zero sentinel followed by the raw backward records;
`children_records` gives their actual backward execution order. Each record is
stored as the exact signed16 encoded axis/radius word and displacement word.
Terrain feature boundaries follow F1822:16-byte records until a signed16 zero,
then two bytes consumed. Structural parsing does not calculate expected physics
or establish that every terrain/world branch has been integrated into Main.

Reproof from private original sources:

```
python3 tools/extract_source_collision_programs.py --refresh-original-proof
```

Portable reproduction uses only the archived source spans:

```
python3 tools/extract_source_collision_programs.py \
  --exe /absent/FIRSTENC.EXE --asm /absent/ffe.asm --data /absent/ffedat.asm \
  --output /tmp/ffe_collision_programs.json
```

This reproduces the pinned resource byte for byte. The Godot resource suite
checks every span, all149 descriptors against separately pinned factory data,
all nested references, packed reads and child-list/source-record extents.
