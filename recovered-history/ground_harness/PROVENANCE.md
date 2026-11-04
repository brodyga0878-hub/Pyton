# Recovery from ground_harness conversation history

Recovery date: 2026-11-04. Destination: `/workspace/recovery/from-agent-history/ground_harness`. The empty `/workspace/Pyton` working repository was not modified.

These files were transcribed from complete, visible earlier tool inputs or outputs. This is preservation of previously written/read source, not a new implementation. Byte identity with the unavailable disk cannot be independently checked now; `SHA256SUMS` identifies the recovered copies. No generated game JSON or native fixture was fabricated or recreated from partial samples.

## Complete own apply_patch history

The following include the subsequent small patches visible in this agent's history:

- `scripts/source_ground_pads.gd`
- `scripts/source_city_anchor.gd`
- `tests/test_source_ground_pads.gd`
- `tests/test_source_model_aux_rotation.gd`
- `tests/test_source_model_child_frame.gd`
- `tests/test_source_city_anchor.gd`
- `tests/test_city_placement.py`
- `tools/build_ground_pads_reference.py`
- `tools/build_model_child_frame_reference.py`
- `tools/build_city_placement_reference.py`
- `docs/ORIGINAL_CITY_PLACEMENT_RU.md`

Final corrections preserved: model descriptors are68bytes; child-frame controls include INT_MIN/MAX extra scales and wrapped F1685 exponent handling; city placement checks the SAR4 pattern at0x2aa4b, the340byte object template, real Int64Abs constants, and separate input/output project paths. Ground-pad generator retains original constructor context validation and the final5832case scope.

## Complete files read through tools

These are the complete snapshots read by this agent, possibly earlier than another agent's final changes:

- `scripts/ground_coordinates.gd`
- `scripts/terrain_surface_point.gd`
- `scripts/source_model_vm.gd` (snapshot with auxiliary rotation; VM owner may have later changes)
- `tests/test_source_model_vm.gd`
- `tests/test_terrain_surface_point.gd`
- `tests/test_terrain_game_query.py`
- `tests/test_terrain_provider.py`
- `tools/native_reference.py`
- `tools/extract_ship_registry.py`
- `tools/extract_world_models.py`
- `tools/build_ground_reference.py`
- `tools/build_terrain_query_reference.py`
- `tools/build_terrain_game_query_reference.py`

Do not merge a read snapshot over a newer recovered version without comparison. The partial reads of `source_model_mesh.gd`, `terrain_query.gd` and other large files were not presented as complete files.

## Original executable and source dependencies

The uploaded archive is now `/workspace/recovery/Frontier_First_Encounters.rar`. Before the environment loss, the verified executable was:

`/workspace/scratch/ffe-analysis/files/FIRSTENC/FIRSTENC.EXE`

SHA256:

`d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72`

Most extractors enforce this revision through `extract_ship_registry.Image` and `extract_galaxy.EXPECTED`. The complete text of `extract_galaxy.py` was not visible to this agent; its missing import must be recovered separately rather than replaced silently.

Native builders require the reviewed JJFFE assembly package formerly at:

- `/workspace/ffe-upstream/jjffe/ffe.asm`
- `/workspace/ffe-upstream/jjffe/ffedat.asm`
- `/workspace/ffe-upstream/jjffe/ffebmp.asm` (independent original sine resource verification)

No complete copy of those sources is preserved in this agent's context. They were external reviewed JJFFE sources; the original fetch URL/commit is not present in this agent's visible history, so no repository address is asserted here. Do not treat the user RAR's ready-made EXE as containing this missing assembly text.

Additional read-only references used before loss:

- `/workspace/ffe-upstream/ffed3d/doc/srctools/cstarport.txt`
- `/workspace/ffe-upstream/ffed3d/doc/srctools/csysgen.txt`
- `/workspace/ffe-upstream/ffed3d/doc/srctools/cphys.txt`
- `/workspace/ffe-upstream/ffed3d/doc/srctools/plstate.txt`
- `/workspace/ffe-upstream/ffed3d/doc/jongware/ShowMesh.txt`

The assembly is authoritative where decompiler comments disagree: cstarport swaps model86/89 pad-table comments. JongWare's model96 label is a research annotation, not an embedded executable descriptor name.

## Missing data and generation order

No complete original generated JSON text survived in this agent's visible history. The following are missing, not silently reconstructed:

- `data/ffe_ground_coordinates.json`:16384 original Q31 table words.
- `tests/fixtures/ground_coordinates_reference.json`:675 original F874/F1674 controls.
- `data/ffe_ground_pads.json`:5tables,16vectors, model81..90 mapping.
- `tests/fixtures/ground_pads_reference.json`:5832 original F650 controls.
- `tests/fixtures/model_child_frame_reference.json`:1776 original F1750 controls.
- `tests/fixtures/city_placement_reference.json`:373contexts ×2variants =746 results.
- `data/ffe_world_models.json`:150original descriptor/geometry closure models for roots72..90.
- `data/ffe_handcrafted_records.json`:native F875 records and actual UID/model pairs.
- `data/ffe_terrain_query.json`:original terrain resource tables, masks and model117..133 collision payloads.
- `tests/fixtures/inhabited_system_reference.json` and `special_system_reference.json`:additional UID provenance.
- `tests/fixtures/terrain_game_query_reference.json`, `terrain_query_reference.json`, `model_vm_reference.json`, `model_aux_rotation_reference.json`, and all other generated fixtures referenced by restored tests.

Required missing source modules for restored code include `extract_galaxy.py`, `extract_settlement_rules.py`, `extract_worlds.py`, `build_terrain_provider_reference.py`, `scripts/source_model_vertices.gd`, `scripts/source_model_mesh.gd`, `scripts/terrain_query.gd`, `scripts/terrain_math.gd`, and `scripts/ffe_math.gd`. Other agents may recover them. The complete `uid_representatives` function was read, but its provider module was only partially read; a labelled excerpt is kept separately under `source_evidence`.

With actual dependencies restored, generation follows: archive/galaxy/world extractors → ground-reference sine and constructor controls → pad reference; archive world-model extraction → child-frame reference; actual F875 records plus inhabited/special provenance and reviewed terrain source → city-placement reference. Builders write JSON only after native execution and their own checks complete.

## Prior verified results (historical, not rerun after recovery)

- Ground pads:5832 native cases,42167Godot checks,0failures.
- Auxiliary rotation:1809 native cases,5362Godot checks,0failures.
- Child frame:1776 native cases,14210Godot checks,0failures.
- City anchor:746 native placement results,16418Godot checks,0failures.
- Focused Python city-placement suite:4tests passed, including complete native regeneration.
- Original coordinate controls:675cases; terrain primitives2016cases/10080outputs.

Godot version used was4.6.3.stable.official, commit prefix`7d41c59c4`; native toolchain was Linux x86_64 GNU`as --64`, `ld -m elf_x86_64`, `nm`, with Python3. These tests cannot presently run from this isolated recovery directory because required data/source dependencies are missing. Recovery verification is limited to parsing the restored Python source and producing checksums.

## Not recoverable as complete text here

Older own builders for body rotation, model vertices, model scalar VM, auxiliary rotation, and terrain primitives were summarized or only partially printed after context compaction. Their complete source is not recreated from algorithm descriptions. The original `docs/ORIGINAL_DISTANCE_UNITS_RU.md` was not fully printed; factual derivation notes are preserved separately and explicitly labelled as recovery notes.

No full FlightModel, main scene, main.gd, Surface, Profile, OriginalGlobe, or game core file was directly preserved in this agent's complete visible reads. No replacement gameplay code is supplied.
