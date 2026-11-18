# Original DOS mission resource graph

`original-spans.json` records eight contiguous, file-backed regions of the
uploaded, pinned DOS executable, VA **0x4801c4..0x49aa16**, totaling **108626
bytes**. The source executable SHA256 is
`d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72`.
The first18-byte expression uniquely anchors the beginning. The complete
1088-byte expression metadata and324-byte vector table each also match their
reviewed source numeric bytes uniquely in the executable.

The captured image contains105 module-descriptor roots,337 block headers and
their clause-pointer arrays,68 expression metadata rows,27 vectors,68 name
lookup records,468 NUL-terminated mission strings and12 event-function words.
All original resource bytes are kept, including opaque statement bytecode;
the extractor does not pretend to execute or semantically parse F31/F41.
The resource image does not include every world/model/UI dependency of a VM.

Descriptors have variable-length arrays beginning at byte28. The extractor
scans actual backward pointers only when they address complete block headers
with bounded clause arrays. Every discovered array length is independently
cross-checked against the named JJFFE source descriptor's byte extent. All105
checks agree, producing337 blocks. This is an explicit structural-boundary
policy, not an assumed uniform32-byte descriptor size or a semantic bytecode
length inference. The full original image remains available regardless of
those decoded boundaries.

Block header+0 names the **initialization statement stream executed by F41**.
It is not a guard expression. Clause pointers at+8 name F31 conditions followed
by F41 statements. Four modules have cleanup blocks:17→3,40→1,54→1,80→3. The
Events projection follows the actual F54 dereference to the initialization IP.
For the other modules, the projection's cleanup0 is only an unused admission
placeholder; callers must reject fabricated priority5 cleanup on those modules.

The ten module-static words share a single40-byte owner at
**0x60bde0..0x60be04**. The first32 bytes are file-backed zeros; the last8 are
the PE section's zero-filled virtual tail. They are separate from the event
register window at0x60be08. Initialization is for a new owner; dispatch must
not reset those static words or allocate a private copy for each task.

JJFFE is a separately pinned variant, not replacement original data. Module32
(`DATA_001359`, original descriptorVA0x48b238) has **15** variable words in DOS
and **16** in JJFFE. The complete scalar-header comparison records this
difference. Other possible bytecode differences have not been exhaustively
classified. Original DOS bytes remain authoritative.

## Reproduction

The default command uses committed captures only and needs Python3:

```sh
python3 tools/extract_source_mission_programs.py --output /tmp/mission.json
```

All four private EXE/assembly paths may be absent. Independent reproof uses:

```sh
python3 tools/extract_source_mission_programs.py --reprove-original \
  --exe /path/FIRSTENC.EXE --asm /path/ffe.asm \
  --data /path/ffedat.asm --mission-asm /path/ffebmp.asm \
  --capture /tmp/original-spans.json --output /tmp/mission.json
```

Both modes reproduced the resource byte for byte; original reproof also
reproduced the capture exactly. See `rebuild-verification.json`.

`SourceMissionPrograms` pins the file SHA and the entire canonical graph,
including every raw span and pointer association. Its bounded read and copied
descriptor/block/text APIs retain logical original resource addresses without
serializing host pointers. `events_definitions()` supplies105 actual descriptor
and variable-count records to the existing F51 allocation kernel. The suite
passes **4460 checks /0 failures**, including all105 real F51 module admissions,
raw pointer/string/metadata checks and forged-resource rejection. Source SHA
maps and numeric failures are written only to ignored build test reports.

No complete mission VM, Main integration, gameplay mission completion or
physical Android result is established by this resource checkpoint.
