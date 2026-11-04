# Recovery from agent history: source_terrain_revision

Recovery date: 2026-11-04. Destination is separate from the empty working repository.

These files were recovered from complete source texts retained in this agent's earlier tool calls/context. They are historical source recovery, not newly designed replacements. Original-environment binary files and the source ZIP were unavailable. The SHA256 manifest records the recovered copies, not a comparison with the lost original filesystem.

## Complete recovered source files

| File | Provenance and version |
| --- | --- |
| scripts/body_rotation.gd | Complete authored source; pure original F880/F866/F1675 Q31 primitive. No later changes to this file are known. |
| scripts/terrain_query.gd | Complete authored original F1876 query-only integer port, including final invalid-query, cached-feature-edge and resource-cache fixes. The final midpoint workers were independently recovered by this agent's original worker from its own full tool-call text and appended unchanged. |
| scripts/terrain_surface_point.gd | Complete authored F581 model-local point-to-query-frame wrapper, including signed-width, zero-distance and shift corrections. |
| scripts/source_polygon.gd | Complete authored pure-Godot even-odd slab tessellation helper, including the explicit integer type parse fix. |
| scripts/spherical_terrain.gd | Complete last own source: CITY_REVISION sphere-source-cities-v3, retaining v1/v2 geography and terrain paths. Depends on the separately owned source_city_profile.gd. |
| scripts/surface_orbit_link.gd | Complete last own source, including explicit terrain revision metadata and legacy defaults. |
| scripts/near_surface_view.gd | Complete last own CITY3 source, with context revision selection and cached city binding. Depends on Surface.bind_city from the lost SurfaceModel. |
| scripts/ground_coordinates.gd | Complete earlier read of the parent's source, not authored by this agent. Original Q31 F874 coordinate conversion. |
| scripts/source_units.gd | Complete earlier read of the parent's source, not authored by this agent. Verified source-unit conversion. |
| scripts/terrain_math.gd | Complete earlier read of the parent's source, not authored by this agent. Original integer terrain hash/jitter primitives. |

## Complete recovered tests

The three tests below are recovered complete source texts, but their native fixture JSON files are not recovered here. Historical pass counts are context evidence only; they were not rerun in this replacement environment.

| File | Last historical verification in retained context |
| --- | --- |
| tests/test_body_rotation.gd | 11,214 checks; 1,400 native cases, 682 updates. |
| tests/test_terrain_query.gd | 11,994 checks; 336 empty, 608 actual-model, 608 paired empty and 120 original caller queries; 87 feature effects. |
| tests/test_terrain_surface_point.gd | 1,450 checks; 120 original F581 matrix/center/altitude cases. |

## Partial material

partial/worker_functions.gd.txt is the exact 102-line midpoint-worker source recovered by child terrain_worker_analysis. It is already included at the end of scripts/terrain_query.gd. Its companion provenance records the worker's independent SHA256. It is retained separately as evidence, not an additional runtime file.

partial/SURFACE_MODEL_RECOVERY_NOTES.md contains implementation notes only. It is explicitly not recovered source text and must not be copied as a historical original.

## Missing dependencies and limits

* No complete native-generated JSON was present in the retained context. No data file or fixture was fabricated or zero-filled.
* Required data includes data/ffe_ground_coordinates.json and data/ffe_terrain_query.json. The latter was an independently extracted resource dataset v2 with models 117..133; model 117 is anisotropic and excluded from the spherical provider. Actual original resource bytes must be restored or extracted again.
* Required native test fixtures include body_rotation_reference.json, terrain_query_reference.json, terrain_model_query_reference.json and terrain_game_query_reference.json. Additional later fixtures (390 supplemental points and 1,040 provider controls) were produced by other agents and are not reproduced here.
* scripts/surface_model.gd was not recovered as a complete continuous source text. No invented full file has been supplied. Neither Main, FlightModel, Navigation, UI nor the planetary provider was continuously available in this agent's retained text.
* The complete text of tools/build_source_polygon_reference.py and tests/test_source_polygon.gd did not survive the final retained context, despite historical authorship. Their code is not recreated from a remembered algorithm. Their historical oracle used host libGLU GLU_TESS_WINDING_ODD, two actual source shapes (model244@232 and model242@68), and six analytic shapes. The shipping helper uses pure Godot; historical tessellation verification had 22,590 passing checks.
* source_city_profile.gd and source_city_runtime.gd were owned by other agents. The parent subsequently changed the CITY3 profile's grade plane to the actual native X-cross-Z normal and enlarged flattening footprints after QA. These separate changes are expected dependencies of the recovered Sphere source; an earlier ideal-plane Profile version must not silently replace them.
* The latest CITY3 integration was not a released APK. Historical live checks for the actual New Moscow model84 recorded 25,646 triangles, safe entry, landing/takeoff/save/orbit/reentry. Some grading-footprint fixes were still owned by the parent.

No working-repository source, generated resource or project configuration was changed by this recovery bundle.
