# Recovery from this agent's retained tool-call history

Recovered by `/root/ground_vector_source` into a separate recovery directory on 2026-11-04. Nothing here was written to `/workspace/Pyton` during recovery.

## Complete last-known owned files

The files below were reconstructed from their full creation/read tool texts and all subsequent patches retained in this agent's conversation. No old filesystem hashes were recorded, so byte identity with the inaccessible disk is not independently asserted. These are preserved implementations, not newly designed substitutes.

- `scripts/source_model_vertices.gd`: complete full file read, plus the recorded uninitialized-parameter and explicit chosen-PRNG-state patches.
- `scripts/source_model_vm.gd`: complete full file read, plus recorded auxiliary-rotation/material helpers.
- `scripts/source_model_mesh.gd`: full creation patch plus every retained subsequent patch: source primitive/compiler fixes, multi-contour/slab fallback integration, source colour propagation, normals/cones/sprites, source sort hints, native F1750 s32/anchor corrections, explicit static PRNG profile. Requires the separately authored `source_polygon.gd`, `ground_coordinates.gd`, and generated source assets.
- `scripts/source_city_runtime.gd`: complete creation patch plus recorded conservative broadphase margin and seed-validation patches. Last old-environment focused run passed 45 checks. **The final requested `footprint_m` / `flat_inner_m` guard had NOT been implemented before the environment disappeared.** Do not infer that it is present or tested.
- `tools/extract_world_models.py`: complete full file read plus its last descriptor-field patch (`phys_scale`, `frustum_radius`, `primitives`, `outer_radius_q8`, `inner_radius_q8`). Depends on original `tools/extract_ship_registry.py` (`Image`, `DESCRIPTORS`), not retained as a full file here.
- `tests/test_source_model_mesh.gd`: complete creation plus recorded expansions/sort-hint checks; last old-environment run passed 2036 checks.
- `tests/test_source_city_runtime.gd`: complete creation plus the actual-plane/F650 quantization correction; last old-environment run passed 45 checks.
- `tests/test_world_model_assets.py`: complete creation plus JSON-key normalization and unused-import removal; last old-environment run passed all four tests.
- `docs/ORIGINAL_WORLD_MODELS_RU.md`: complete creation and all retained subsequent documentation patches, including source-PRNG, painter-depth, native-child-frame and city-runtime findings. Historical API-name references were preserved rather than silently updated.
- `tests/test_source_model_child_frame.gd`: complete verbatim tool read of the other agent's test, then no observed changes. Last old-environment run passed 14210 checks against 1776 native controls. Native fixture/builder were authored by `/root/ground_harness`, not recovered from invented values here.

## Generated data and evidence not recreated

`data/ffe_world_models.json` was never printed in full. It is deliberately NOT fabricated. The recovered exact extractor can regenerate it when the original EXE and its `Image` helper are restored. Last known source EXE SHA-256: `d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72` (2,097,152 bytes); root models 72..90, 150 models in reference closure. RAR and EXE are different artifacts/hashes.

The complete native fixtures and builders for model vertices, VM arithmetic, auxiliary rotation, child frames, terrain, body rotation and ground coordinates were not in this agent's full tool outputs. Their metadata, counts and summaries are not enough to recreate authoritative controls. Obtain those full texts from the owning agents or regenerate using their exact recovered native harnesses.

`tests/test_source_model_vertices.gd` and `tests/test_source_model_vm.gd` were implemented earlier but their complete creation texts were not present after the retained compaction. They are not invented here. Same applies to the complete early research documents `GROUND_COORDINATES_SOURCE_RU.md` and `ORIGINAL_BODY_ROTATION_RESEARCH_RU.md`: only summaries survived; any recovered notes about them must be labelled partial.

No complete FlightModel, main/UI, Navigation or PlanetarySystem original file was available in this agent's retained outputs. Never substitute this small geometry recovery for the lost whole game.

## Historical snapshots

Files under `historical_snapshots/` are complete earlier tool-read snapshots of files owned by other agents. They may be useful bases for replaying those owners' later patches. They are explicitly NOT asserted to be the latest implementation. These include complete reads of `segment_triangle.gd`, `source_units.gd`, `ground_coordinates.gd`, `source_ground_pads.gd`, `source_city_profile.gd`, the initial `source_model_visual.gd`, and pre-Source3 `spherical_terrain.gd`. The visual snapshot precedes its owner's later conversion-basis/decal-layer patches, and the terrain snapshot supports only sphere-v1 and source-sites-v2. In particular the earlier SourceCityProfile did not yet contain the later actual-native-plane grading, radius in key, or enlarged 192-source-unit footprint policy.

## Verification at recovery time

The old Godot/native runs listed above are historical evidence, not tests rerun after the machine loss. Full dependencies/data are absent in the new environment. Recovery-time checks are limited to file inventory and Python syntax unless explicitly recorded later.
