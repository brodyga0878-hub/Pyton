# Recovery from the retained history of /root/world_gap_audit

Recovered on 2026-11-04. Files are written only to this recovery directory; the working repository is not modified.

## Full observed source files

The retained tools output from the read-only audit preceding block 10.18 (baseline 0.10.6-alpha1 / block 10.17) contained complete reads of the following files. They have been transcribed without new implementation or inferred missing functions:

| Recovered file | Historical command / completeness |
|---|---|
| `scripts/original_worlds.gd` | `sed -n '1,135p' scripts/original_worlds.gd`; output through the final `return not context.default_id.is_empty()` |
| `scripts/procedural_worlds.gd` | `sed -n '1,130p' scripts/procedural_worlds.gd`; output through the final `return true` |
| `scripts/body_initializer.gd` | `sed -n '1,100p' scripts/body_initializer.gd`; output through the final dictionary return |
| `tools/extract_worlds.py` | `cat tools/extract_worlds.py`; full file including its CLI entry point |
| `tools/extract_settlement_rules.py` | `cat tools/extract_settlement_rules.py`; full file including its CLI entry point |
| `tools/native_reference.py` | `sed -n '1,90p' tools/native_reference.py`; full file through `return lines,hashes` |

`docs/GROUND_COORDINATES_RESEARCH_RU.md` is restored from the complete original `apply_patch` input in this agent's own history, written while the parent was packaging 10.18. It describes the research state at that time, not the status of later geography work.

## Observed fragments only

- `partial/scripts/main.surface_action.v0106.gd`: one complete `_surface_action()` function, assembled from overlapping historical `sed -n '1735,1810p'` and `sed -n '1770,1805p'` reads. It is not a complete Main file.
- `partial/scripts/planetary_system.observed_functions.gd`: complete observed functions `protect_surface`, `snapshot`, `is_orbital_site`, `begin_site_transfer` only. Their original locations were separate slices of `scripts/planetary_system.gd`; omitted intervening code has not been invented.
- `partial/scripts/inhabited_world_rules.observed_functions.gd`: complete `_white_dwarf`, `_append`, `_ground` from `sed -n '70,105p' scripts/inhabited_world_rules.gd`; the complete class was not read.
- `partial/upstream/jjffe/ffe.FUNC_000874.asm`: complete observed F874 procedure from the old upstream file `/workspace/ffe-upstream/jjffe/ffe.asm`, read by slicing from `FUNC_000874:` up to `FUNC_000875:`. Only this procedure is restored, not the upstream assembly file. Trailing blank lines are normalized.
- `partial/data/ffe_settlement_rules.observed.json`: all fields were visible in a historical full Python `repr` (the command printed `str(d)[:5000]`, and this dictionary's printed form fit within that bound). JSON whitespace is newly serialized, not the original byte layout. **Do not use this entire file as a trusted runtime asset yet:** literal template strings `12` and `16` as recovered measure 71 bytes, while the source constructor expects 68; no speculative trimming was applied. Templates `2` and `17` measure 68 bytes. All three numeric tables are independently validated against their historical SHA256 values after packing as little-endian u32: ground_coordinates 32 entries, ground_models 48 entries, orbital_models 12 entries. Their hashes match. Original world data `ffe_worlds.json` was printed only as a prefix and has not been recreated.

## Scope and limits

No complete FlightModel, Navigation, Galaxy, Main, economy, combat, campaign, or README text was present in this agent's audit history. The history contains other old surface/near-view files already recovered by the parent team's other agents; they were not duplicated here. No new game behavior, generated fixture, guessed resource data, or missing code was substituted for unavailable source.

Other old agent names visible in inherited context: `coverage_shaders`, `preview_review`, `release_audit`, `transition_review`. No identities from stages 1–9 were visible.

Recovery validation checks source syntax with Python AST parsing, records checksums of restored files, and verifies the three historical numeric-table hashes. This is transcription validation only; no claim that the incomplete recovered project builds or runs is made.
