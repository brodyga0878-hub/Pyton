# Production Main native landing trial

`tests/test_native_landing_trial_main.gd` instantiates the real Main scene with
private capture settings and private test save/report directories. It reuses
the existing source Earth entry helpers; no original player slot is read or
written. Result: **48 checks, 0 failures**.

The test enters the explicit native mode through `_start_native_landing_trial`,
retains the six original model references, deploys gear with real Main commands,
and flies from the native50m entry to accepted source contact using `_tick`.
The ordinary save payload and generation do not change during the trial. The
real separate SaveStore persists the source landing; parked idle does not
reclassify its previous hit. A valid ordinary save deliberately written as the
newest native slot is skipped, and the older valid native slot cold-loads via
the typed production factory. Mismatched clock and incomplete parked gear
candidates are rejected without changing live objects.

The production takeoff command queues departure without a position jump; the
next powered `_tick` releases the restored park. Actual out-of-chart rejection
preserves all six current owners. Exit returns the exact original references
and ordinary HP/RNG/fuel/gear/time and saved payload/generation.

`_advance_controls(0.3)` exercises a real three-substep frame. All three accepted
native copies are published despite Flight reference replacement; source
generation and celestial time account for the entire frame. Native mode forces
ordinary time and leaves neither a pending plan nor catch-up debt. A rejected
frame closes its plan without counting a failed physical step.

The actual production report action creates a ZIP with `report.json`, checksum
manifest and opt-in `game-save.json`. The top-level save preserves the complete
native source-session and provider witnesses byte-for-byte through JSON, without
the bounded context collector's depth/string truncation. The real whole-game
decoder validates the saved state extracted directly from the archive.

This test covers explicit bounded manual native landing. It does not establish
full F569/F570 object-bank dispatch, autopilot or physical Android performance.
