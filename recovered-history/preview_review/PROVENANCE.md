# Recovery from /root/preview_review history

Recovery date: 2026-11-04. No repository files have been edited. This directory is a recovery quarantine, not a claim that these are the final 0.10.8 files.

## Complete own-history reads

- `scripts/celestial_renderer.gd`: complete `cat scripts/celestial_renderer.gd` output in the first technical-review tool result, before parent implemented the near-surface visual bridge. It is the pre-bridge 0.10.4 renderer (64/32 sphere, atmosphere, rings and update_view). Parent subsequently changed focus hiding; that later complete revision is not available in my own reads.
- `versions/pre-v2/scripts/surface_orbit_link.gd`: complete `cat scripts/surface_orbit_link.gd` in that same result; `REVISION="orbit-link-v1"`, plus-spin longitude rule, original +Z physical direction. Historic exact version, not latest.
- `versions/pre-v2/scripts/near_surface_view.gd`: complete `cat scripts/near_surface_view.gd` in the second read tool result. This is the intermediate pre-V2 implementation. It contains the initial affine local coordinate adoption and no V1/V2 preview gate. The parent later corrected both. Do not use this version as the final bridge.

## Partial own-history reads

`partial/scripts/main.v0104._process.gd` is the complete function visible inside `sed -n '795,898p' scripts/main.gd` in my first read. Original containing range is 795–898; exact function start/end line numbers were not separately printed. It is pre-near-surface-bridge code, though extended flight was already present.

`partial/scripts/main.v0104._jump_action.gd` and `main.v0104._apply_system.gd` are complete functions visible inside `sed -n '1370,1420p' scripts/main.gd` in the same read. Original containing range 1370–1420, exact function line numbers not printed. They must be merged into a full main script, not treated as standalone full project files.

Source text is transcribed from the retained literal tool outputs. Old filesystem hashes are unavailable, so an independent byte-for-byte comparison to the unavailable old machine cannot be performed. Recovery hashes describe these recovered files only.

## Authored test

`tests/test_near_surface_view.gd` will be restored from my complete original heredoc plus the two subsequent literal Python replacements. Final historical output was `NEAR SURFACE VIEW TESTS: 240 checks, 0 failures`. This test predates 0.10.8 source-terrain changes.

## Scope not available in my own complete reads

No complete Flight/Nav/Galaxy/Planetary/main/UI implementation from stages 1–9 was read by this agent. No JSON data files or early agent names are present in my own history. I will not invent replacements under those paths.

Full source_model output from the inherited parent transcript, if restored, will be separately labelled as inherited transcript material and historic version, never as my own complete read.

## Complete inherited-parent SurfaceModel

`scripts/surface_model.gd` is the 440-line **0.10.4-alpha1 pre-bridge** implementation, recovered from an inherited full parent `cat scripts/surface_model.gd` (0.10.2), followed by all literal parent edits introducing OrbitLink/V5 (0.10.3) and controlled vertical flight/V6 (0.10.4). Those tool calls are visible in this agent's inherited transcript; they are not my authored implementation and not a direct full read performed by this child.

Cross-check against my own later partial reads: the recovered file has `touch_down` at line 165, `leave` at 183, `_restore_globe` at 345, `enter_from_orbit` at 379 and `begin_descent` at 406, matching the original printed line references. Original functions visible directly in my own read align with this recovered version. This version predates the world-Z/handedness fix; its `leave` uses `globe.basis_at(ll[0],ll[1])`. It predates NearSurfaceView adoption, real source terrain, source city triangles and all 0.10.6–0.10.8 changes. Merge newer precise suffix/prefix evidence separately rather than treating this as latest.

The test file is now restored from its original heredoc and the exact two replacement blocks: first 182 checks, then +50 basis checks and +8 V1 compatibility checks, with historical final output `240 checks, 0 failures`. It requires the V2 embedding and cannot pass against the quarantined pre-V2 near-view/orbit-link files without the parent's later patches.

## More inherited main functions

- `partial/scripts/main.v0104._physics_process.gd`: full function from inherited `sed -n '680,790p'` at the start of the globe work, with literal later parent patches inserting frame-index/camera rebasing and V6 vertical handoff/keyboard cancellation. Own subsequent partial read of main 795–898 provides its dock/death/autosave tail. Contains no near-preview changes.
- `partial/scripts/main.v0101.map_help_functions.gd`: complete `_build_map`, `_refresh_map`, `_show_map`, `_close_map`, `_show_help` visible in the inherited full `sed -n '1190,1348p' scripts/main.gd` output during 0.10.1 graphical work. This is the older known literal UI version, not reconstructed 0.10.8 UI.

Independent corroboration: on 2026-11-04 the recovered 440-line SurfaceModel matched `/workspace/recovery/from-agent-history/release_audit/versions/v0.10.4-history-patches/scripts/surface_model.gd` byte-for-byte (`diff -u` empty), independently recovered by that agent's own patch replay. This corroborates this historical version, not any later revision.
