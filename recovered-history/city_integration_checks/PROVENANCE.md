# Recovery from /root/city_integration_checks historical tool calls

Recovered on 2026-11-04 into this recovery directory only. The unavailable original workspace was not read, and the replacement `/workspace/Pyton` repository was not modified. This package contains historical text, not a new implementation. Native fixtures, complete data files, an APK and the previous source ZIP were not regenerated or fabricated.

## Complete files

| File | Exact historical source and version |
| --- | --- |
| `tests/test_source_city_integration.gd` | Original complete `apply_patch Add File` issued by this agent, replayed with its two subsequent actual patches: actual-triangle radial footprint instead of AABB-corner bound; then the two unsupported underground model96 checks, actual airfield81/82 landings, and hard source pad contact. Final239lines. Historical backtrace references to lines85,107,236 match the restored file. No changes were made to make the test pass. |
| `scripts/original_worlds.gd` | Complete90-line `sed -n '1,90p' scripts/original_worlds.gd` output read by this agent during Source3 integration. This is the post-0.10.8 source with `GroundCoordinates`, `ffe_handcrafted_records.json`, initialized source seed/record metadata on bodies and settlements, and raw body rotation fields. Its `return not context.default_id.is_empty()` is the final line of the historical output. Compared with the79-line `world_gap_audit` recovery, it preserves the11 actual later source lines rather than inventing replacements. |
| `scripts/ship_catalog.gd` | Complete11-line output of this agent's `sed -n '1,120p' scripts/ship_catalog.gd`. |

## Last actual test state

The final historical run of the239-line test reported:

```text
Source city integration elapsed: 13.95 seconds
SOURCE CITY INTEGRATION TESTS: 347 checks, 10 failures
```

The10 failures were six real insufficient terrain grading footprints and four checks for the still-pending atomic unsupported model96 entry rejection. Both model96 ports, Apollonius City and Factory Central, still admitted the older open-air fallback in that observed run. The new tests deliberately exposed that pending implementation. This is not a green test or a verified release checkpoint.

The six footprint failures persisted after replacing the AABB-corner radius with the actual maximum XZ radius of the compiled triangles:

| Actual control | Solid mesh radius m | Profile inner grading radius m |
| --- | ---: | ---: |
| London model84 | 35497.49 | 32523.21 |
| Tokyo model90 | 40117.48 | 33468.75 |
| Amundsen model85 | 6503.59 | 4791.16 |
| Native procedural model88 | 5628.16 | 3506.24 |
| Native procedural model86 | 4221.11 | 2645.68 |
| Native procedural model87 | 4640.50 | 4332.37 |

The original model84 New Moscow approach, actual model81/82 airfield landings, landed JSON restore, takeoff, orbit/preview/re-entry, hard pad contact and missing-metadata atomic entry/restore checks had no failures in that347-check run. The broad claim is limited to these observed test cases. New Moscow is model84 with UID0xbdd3aa2e; model89 with that UID was only an earlier controlled preview, not actual New Moscow.

No footprint guard or192-grade policy was applied by this agent before the old environment became unavailable. Later intended changes to Source3 floor plane alignment, collider height and model96 rejection must be recovered from their owners' actual patches, not inferred from this package.

## Raw partial reads

All files under `partial/` are incomplete historical reads and must not be copied over whole production files. No missing lines were guessed. The line ranges in filenames refer to the original `sed` commands, not a single guaranteed final revision; Source3 was being edited concurrently.

| Raw fragment | Historical command and version distinction |
| --- | --- |
| `partial/scripts/surface_model.gd.lines075-150.txt` | Exact76lines from `sed -n '75,150p'`: Source3 entry, atomic candidate city preparation, `bind_city`, and beginning of flight stepping. At this read `_prepare_city` still treats models outside81–90 as no-city success, including96. |
| `partial/scripts/surface_model.gd.lines151-208.txt` | Exact58lines from later `sed -n '151,208p'`: geometry-aware approach cruise, climb before lateral approach, touchdown and start of takeoff. |
| `partial/scripts/surface_model.gd.lines245-325.earlier.txt` | Exact81lines from the earlier `sed -n '245,325p'`: save restoration and then the pre-CCD building functions. Its last line is the older `for box in buildings()`. It overlaps the *later*325–390 fragment at a different source revision; do not join blindly by line number. |
| `partial/scripts/surface_model.gd.lines325-390.later.txt` | Exact66lines from later `sed -n '325,390p'`: source ellipsoid CCD dispatch, source floor contact and most of the source facade collision handler. At this observed version radiiY is `maxf(1.0,span*0.12)`, not the subsequently discussed `clearance(ship)` policy. The final line is the facade damage assignment; subsequent velocity/braking lines were not in this read. |
| `partial/scripts/surface_model.gd.lines398-488.txt` | Exact91lines from `sed -n '398,488p'`: native pad XZ, terrain landingY, rebase, source city preparation before globe restore mutation, orbit entry and start of ascent validation. |
| `partial/scripts/surface_model.gd.lines489-545.txt` | Exact57lines from later `sed -n '489,545p'`: rest of ascent, geographic descent/re-entry and vertical stepping through `if flight_phase=="ascent":ready_for_orbit=true`. Missing tail not supplied. |
| `partial/scripts/planetary_system.gd.lines001-140.txt` | Exact140lines from `sed -n '1,140p'`: original/procedural world selection, layout metadata, solar/prototype hierarchy construction and relative Kepler orbital coordinates. Complete file was not read. |
| `partial/scripts/flight_model.gd.lines001-105.txt` | Exact105lines from `sed -n '1,105p'`, including the original blank line105. This closes the historical gap99–104: station contact normal, position, reflected velocity, autopilot cancellation and notice. Complete file was not read. |
| `partial/data/ffe_handcrafted_records.selected-native-records.txt` | Exact one-line Python dict output from reading only records5,9,10,108. These are actual68-byte initialized native records, not a reconstructed full JSON resource. It is deliberately raw text under `partial/`; do not substitute it for the133-record data file. |

Other completely read modules such as `source_city_runtime.gd`, `test_source_ground_pads.gd` and `test_source_model_mesh.gd` already have complete owner recoveries in sibling directories. They were not duplicated here. No new test run was attempted against the incomplete recovered project; the counts above are historical observations only.
