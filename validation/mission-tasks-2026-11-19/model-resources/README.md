# Original model catalog inputs for F36

The capture retains **466 table slots**, **465 complete68-byte descriptors**,
their collision first bytes, **84 optional24-byte physical specifications**
and the actual15-word drive mass table. Slot149 is the only NULL model pointer.
All465 non-null descriptors and their admitted pointer targets are mapped in
the pinned original DOS executable.

Table extent has two independent original-code bindings: whole F1538 reads
DATA4681 at0x4d0cfc; whole F1345 indexes adjacent DATA4682 at0x4d1444. Thus466
is established from actual DOS code operands, not from a presumed JJFFE count.
The named JJFFE table is separately cross-checked as466 rows with NULL149.
It supplies names only; actual descriptor and target bytes come from DOS.

There are **1016 exact spans**, summing **36025 captured bytes** (overlapping
or shared source locations may be represented by several model-specific spans).
The resource source executable SHA256 is
`d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72`.
Assembly, data assembly and model/mission assembly have separate pinned hashes.
Every previously admitted0..148 factory projection and existing153/155 effect
projection remains exact. Prior resource files are unchanged.

This is the full catalog projection required by F36. Other descriptor words
may point to mesh, texture, full collision programs or other world resources;
their pointed content is not claimed captured merely because a descriptor is
present. New raw model IDs are not a claim that Main renders all those models.

Default extraction requires the included capture only:

```sh
python3 tools/extract_source_mission_models.py --output /tmp/models.json
```

--capture selects another copied capture. All four original paths may be
absent. Independent original reproof uses --reprove-original with --exe,
--asm, --data and --mission-asm; both the resource and capture reproduced
byte for byte. The Godot loader validates the exact canonical graph/file hash,
returns copies and rejects forged catalogs before copying or hashing cycles.
