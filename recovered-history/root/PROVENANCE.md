# Recovery from the root assistant's visible conversation

These five files were restored from complete file-read outputs and their subsequent visible apply_patch edits in this conversation. They are the latest text version visible to this agent; there is no surviving original-file hash to independently prove byte identity.

- `scripts/source_units.gd`: complete original read output.
- `scripts/source_city_profile.gd`: complete original read output plus the visible scalar precision, radius-key and native-plane-normal patches.
- `scripts/source_model.gdshader`: complete original read output.
- `scripts/source_model_visual.gd`: complete original read output plus the visible conversion-basis, per-primitive layer calculation and scalar precision patches.
- `tools/preview_world_model.gd`: complete original read output. Its default model89 with UID0xbdd3aa2e is a diagnostic variant; actual New Moscow is source model84.

## Known unfinished work retained as historical evidence

The recovered `source_city_profile.gd` uses the old `outer*1.05+64` footprint policy. Before the old environment became unavailable, integration checks had found that this region is too small for six tested model footprints. The planned enlarged grading region and a `footprint_m` runtime guard had NOT been applied. This recovery deliberately does not fabricate those later edits or claim the old integration was passing.

Native terrain queries and F879 anchor research remained separate from live city grading. Root elevation0 and modern rendering/decal ordering are adaptations. Original textures and dynamic events were still incomplete.

No complete game, original APK or previously packaged source ZIP has been recovered here. Missing dependencies and resources must be recovered or separately regenerated before running these files. No game test is reported as passed in the new environment merely because its source was recovered.
