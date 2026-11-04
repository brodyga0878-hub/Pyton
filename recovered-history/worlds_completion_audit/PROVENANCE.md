# Recovery provenance — worlds_completion_audit

Recovered on 2026-11-04 into this recovery directory only. `/workspace/Pyton` was not edited. Source: this agent's own retained conversation: literal `apply_patch` creation/update calls and complete `exec_command` file-read outputs. No inaccessible other-agent histories were read. Comparison with other agents' actual recovered files is a comparison of recovery artifacts, not a history lookup.

These are historical source snapshots, **not a complete or runnable project**. No lost generated JSON, upstream assembly adapter or missing core module has been invented. Hashes in `recovered-files.sha256` describe the recovered copies; where no old digest survived, they do not independently prove the old on-disk byte digest. Whitespace/newlines were copied from the literal patch/read contents. `nl -ba` prefixes were removed from full reads.

## Full original texts from own creation patches

| Original relative path | Evidence / state |
|---|---|
| `scripts/source_city_view.gd` | Full original creation patch. Persistent 8-node LRU city view; single selected city. Last own version, before any later root edits. Independently byte-equal to the full copy recovered by `multiplicity_reference`. |
| `tests/test_source_city_view.gd` | Full creation patch plus the explicit `WeakRef` type correction. This is the exact own 33-check version. It intentionally preserves the then-existing test tag `sphere-source-city-v3`; the later actual revision spelling is `sphere-source-cities-v3`. Do not silently treat this as the final post-integration test. |
| `tools/build_terrain_provider_reference.py` | Full creation patch plus explicit follow-up patches: initialized caller altitude, 84-byte output and read-only original loop-level instrumentation. Produces 1040 controls when all original dependencies exist. |
| `tests/test_terrain_provider.py` | Full creation patch plus explicit subdivision-level/altitude-written assertions. Four tests. |
| `tests/test_terrain_provider_points.gd` | Full creation patch; 390 additional + 1040 fixed-provider/sensitivity cases. 19258 checks historically passed before the environment loss. This historical result has not been rerun against a reconstructed project. |
| `docs/SOURCE_TERRAIN_PROVIDER_POLICY_RU.md` | Full creation patch plus own updates adding units cross-link, portable comparison and dense native sampling. |
| `docs/ORIGINAL_TERRAIN_RESEARCH_RU.md` | Complete printed text plus the literal own updates for resource v2, additional controls, portable modules and remaining integration. |
| `docs/STAGE10_21_22_RU.md` | Full original draft creation patch plus the literal model96/plane correction. The header is the then-correct pre-pipeline draft: 0.10.9 not yet built. Later parent build results are not recovered here. |

## Full original texts from complete reads

| Original relative path | Snapshot qualification |
|---|---|
| `tools/build_terrain_game_query_reference.py` | Complete `sed -n '1,260p'` output; optional `model_ids`/`largest_axis_probes` expansion already present. Byte-equal to `ground_harness`'s recovered copy. Depends on the missing `build_terrain_query_reference.py` and `extract_ship_registry.Image`. |
| `tools/build_terrain_additional_query_reference.py` | Complete printed builder for the 13 additional models, 390 controls. |
| `tests/test_terrain_additional_query.py` | Complete printed two-test file. |
| `tests/test_terrain_game_query.py` | Complete printed three-test file. |
| `scripts/terrain_surface_point.gd` | Complete printed F581 pure wrapper. Byte-equal to recovered copies from `source_terrain_revision` and `ground_harness`. |
| `tests/test_terrain_surface_point.gd` | Complete printed 120-case test. Byte-equal to `source_terrain_revision` recovery. |
| `scripts/near_surface_view.gd` | Complete 79-line **pre-Source3** snapshot; no `city_data` propagation. Byte-equal to `geography_regression` recovery. Later integration is known to exist but was not printed in full to this agent. |
| `scripts/spherical_terrain.gd` | Complete 90-line **pre-Source3** revision v1/v2 snapshot. Byte-equal to `geography_regression` recovery. No Source3 `city_profiles`. |
| `scripts/surface_visual.gd` | Complete 147-line **pre-Source3** snapshot. Includes generic pad and ten-box district; later root-owned skipping of those in Source3 is not included. |
| `scripts/source_city_profile.gd` | Complete 46-line early Source3 preparation snapshot. **Superseded**: later root used the actual native X/Z plane normal; that later full text was not printed here. |
| `scripts/source_model_visual.gd` | Complete 102-line **pre-`conversion_basis` API** snapshot. This older one-argument `configure(compiled)` is incompatible with SourceCityView's later two-argument call. The later head was partially read; do not combine snapshots and call the result an exact recovered final file. |
| `scripts/source_model.gdshader` | Complete 19-line printed shader. Byte-equal to root recovery. |
| `scripts/source_units.gd` | Complete 11-line printed source/HUD unit helper. Byte-equal to root/source_terrain_revision recovery. |
| `scripts/world_presentation.gd` | Complete 45-line printed presentation module. Byte-equal to `geographic_descent_model` recovery. |
| `scripts/surface_orbit_link.gd` | Complete 59-line printed orbit-link-v2 helper. Byte-equal to source_terrain_revision/geography_regression recovery. |
| `scripts/device_settings.gd` | Complete 41-line printed settings helper. Byte-equal to `release_audit` recovery. |
| `tests/test_city_collision.gd` | Complete 69-line printed legacy flat ten-box collision test. |
| `tests/test_global_surface.gd` | Complete 110-line printed pre-Source3 globe/streaming test. Later CURRENT_REVISION test pinning is not included. |
| `tools/check.sh` | Complete printed older pipeline: includes multiplicity and terrain primitives, **does not yet include** the later query/city/model test suites. Later root-owned updates unknown here. |
| `docs/ORIGINAL_DISTANCE_UNITS_RU.md` | Complete printed original units research, including HUD factor and model bounds. |
| `docs/STAGE10_19_20_RU.md` | Complete printed historical 0.10.8 release report. Its APK references describe the old environment; no APK artifact was recovered by this task. |
| `docs/RELEASE_ROADMAP_RU.md` | Complete printed historical roadmap at 0.10.8. No claims here about later code/build completion. |

## Explicit fragments, not complete modules

`partials/scripts/main.gd.*.fragment` contain exact bounded printed spans: save snapshot/write/read, commit/load, `_apply_system`, `_surface_action`, `_apply_settings`, site arrival, vertical ascent and `_sync_planet_visuals`/celestial view. They are pre-Source3 snapshots. These files cannot stand in for `scripts/main.gd`.

`partials/scripts/surface_model.gd.lines193-360.fragment` is the exact printed legacy span containing leave, snapshots/restoration, ten-box collisions, pad/geography helpers and recenter. It is neither the file beginning nor the whole Surface module and contains no later Source3 collision hooks.

No complete original `main.gd`, `planetary_system.gd`, `flight_model.gd`, Galaxy/navigation/UI core was present in this agent's retained full text. Earlier compaction retained descriptions, not their complete source. No replacement implementation is supplied under those names.

## Missing source and generated data

Not recoverable as full text from this retained history:

- `tools/build_terrain_query_reference.py`, `tools/build_terrain_model_query_reference.py`, `tools/build_terrain_primitives_reference.py`, `tools/extract_terrain_query.py`, `tools/build_multiplicity_reference.py`, `tools/native_reference.py`, `tools/extract_ship_registry.py`;
- `scripts/sterile_system.gd`, `scripts/world_inputs.gd`, their whole tests and the original multiplicity generator: only descriptions of the 0..5 guards survived, insufficient to claim exact files;
- `data/ffe_terrain_query.json`, including 17-model resource v2; `data/ffe_handcrafted_records.json` and generator-record corpora;
- full JSON fixtures `terrain_query_reference.json` (336), `terrain_model_query_reference.json` (608 plus controls), `terrain_game_query_reference.json` (120), `terrain_additional_query_reference.json` (390), `terrain_provider_reference.json` (1040), `terrain_primitives_reference.json` (2016), `multiplicity_reference.json` (436);
- full dense-sampling report `/workspace/ffe-review/terrain-provider-stress/summary.json` and its external scratch runner;
- full `docs/TERRAIN_MODEL_RESOURCES_RU.md`, `docs/MULTIPLICITY_45_RESEARCH_RU.md`, `docs/WORLDS_RELEASE_GAPS_RU.md`: summaries or partial printed sections survived, but not sufficient for exact original copies;
- original JJFFE `ffe.asm`/`ffedat.asm` and the exploratory native build products.

The generated JSON dependencies must be genuinely regenerated from recovered original builders, canonical upstream source and the uploaded original executable. Fixture values cannot be reconstructed from case counts, sample ranges or a modern port acting as its own oracle. The original uploaded archive is `/workspace/recovery/Frontier_First_Encounters.rar`; canonical EXE SHA-256 recorded in this history is `d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72`.

### Surviving dependency notes (summary facts, not recovered source code)

The missing full native-query builder had 49 source procedures: 1335,1339,1465,1467,1521,1656,1816..1827,1829,1831..1834,1836,1841,1843,1846,1848,1849..1867,1875,1876. Native F581 adds 581,1341,1466,1502,1523,1669. Tables DATA7835..7894 form a contiguous 7476-byte EXE region at `0xedd5c`, including 7220 non-pointer bytes checked against the archive. Both default maps DATA7637/7638 have 16384 bytes. Pointer bytes must retain symbolic relocations; DATA7841+7842 are intentionally read across their label boundary. Native fixed pools are 1500 vertices ×72 bytes and 3000 edges ×16 bytes.

The host adapter required all named FUNC labels normalized to plain numeric labels, signed negative EBP/frame offsets decoded, 64-bit frame-index registers, bare DATA/FUNC immediate operands emitted with `OFFSET FLAT:`, DWORD callback-pointer loads followed by `call rax`, and widened frames for 1849/1851/1853/1855/1857/1866/1867 plus F1669. These are dependency-recovery hints only; they are not the missing adapter's complete implementation.

The original multiplicity block expanded ordinary supported codes from 0..3 to 0..5, while the special-system wrapper remained limited to its verified 0..3 scope. Falaex catalogue ID55619684, seed2388942469, mass150000000, code3 retained an explicit non-advancing-root-step rejection; an isolated native one-second probe did not finish. No exact generator text or full fixture can be recovered from those summary facts.

## Checks performed during recovery

All six recovered Python files were parsed with `ast.parse`; `tools/check.sh` passed `sh -n`. These are transcription/syntax checks only. No full game, native-harness regeneration or APK build was performed in this recovery task. Recovery outputs and metadata are the only writes; the empty Git repository remains untouched.
