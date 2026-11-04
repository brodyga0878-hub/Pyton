# approach_review — recovered historical context

Recovery date: 2026-11-04. No project repository files changed.

These files are transcribed from this agent's retained tool outputs and inherited parent tool inputs. The visible development snapshot is **10.18 / 0.10.7-alpha1, versionCode 20**, during implementation/review, **not a claim of the later final state**. The stage10.17 source ZIP and APK are referenced in history but no longer exist in this machine. No native data JSON is fabricated.

Full files in scripts/ were fully visible in parent reads or this agent's reads. Fragments in partial/ are bounded historical excerpts or whole functions from the much larger main.gd, not a recovered complete main.gd. A suffix named .gd here does not imply standalone compilation. Later revisions may supersede these variants.

The high-return review finding at the snapshot was Surface.leave clamping geoid height to MAX_FLIGHT_HEIGHT (60200); parent was notified. No later fix is known in this agent's context.

Available old agent canonical names in my history: /root/coverage_shaders, /root/preview_review, /root/release_audit, /root/transition_review, /root/world_gap_audit, /root/geographic_descent_model, /root/descent_transition_tests. No stage1–9 agent names are visible.

No complete flight_model.gd, navigation.gd, planetary_system.gd, galaxy.gd, economic/campaign/combat models or main.gd was visible. Their missing portions were not invented.

## Fragment bounds

- main.header.v0106.txt: historical main.gd lines 1–130, ending at `var map_info: Label`; remaining declarations and `_ready` not visible here.
- main.physics_body.v0107.txt: starts at steering computation inside `_physics_process`, ends after hull-loss notice. Function header/guards and any subsequent body are not recovered.
- main.process_prefix.v0106.txt: starts at `speed_slider.input_allowed` inside `_process`, ends at `beam_mesh.surface_begin`; neither the function prefix nor remaining laser/render logic is supplied. The v0.10.7 diff replaces its celestial update with `_update_celestial_view()`.
- main.surface_action.v0107.gd, main.apply_system.v0106.gd, main.controls.v0107.gd, main.geographic_descent_smoke.v0107.gd, main.far_surface_smoke.v0107.gd, main.finish_ascent.v0107.gd contain complete visible named functions, but are fragments of main.gd.
- main.approach_views.v0107.txt is a complete debug-view branch inside `_ready`; outside lines are absent.
- flight_model.equipment.v0106.gd and planetary_system.protect_surface.v0106.gd are complete visible functions only.

Existing recovery cross-check: geographic_descent_model/scripts/celestial_renderer.gd is identical to my fully visible 0.10.7 renderer, including `(global_basis*to_sun).normalized()`. Its partial/scripts/main.sync_planet_visuals.gd also matches my complete visible sync/update functions. Duplicates were not copied.

Full docs/STAGE10_17_RU.md and docs/REMAINING_PLAN_RU.md are the historical 0.10.6 / stage10.17 versions from the initial complete parent read. They describe the earlier band-only state; do not treat them as the status after 10.18.
