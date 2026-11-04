# SurfaceModel: notes only, not a recovered original

The full scripts/surface_model.gd text was not continuously retained. This document preserves known integration contracts to help reconcile another agent's original source. It is not executable code, a synthetic replacement, or a claimed original transcript.

## Last own CITY3 changes

* Added SourceCityRuntime preload and public city_data dictionary.
* Surface.enter accepts a terrain revision defaulting to Sphere.CURRENT_REVISION. Before mutating ship/state it configures a candidate globe and prepares the selected city. A failed compile must leave the prior state unchanged.
* CITY3 initial entry starts at terrain height plus ship clearance plus 1,500 metres. Legacy v1/v2 retain their exact old entry placement.
* _prepare_city accepts wilderness when no eligible source city was selected. Eligible source models 81..90 require a profile and successful Runtime.prepare. Selected source model96 explicitly fails with the Russian underground-port message; the original F650 result for this type is not an exterior landing pad.
* bind_city(site) prepares and then commits city_data, for NearSurfaceView as well as normal Surface entry.
* Save restore prepares city data before mutating state or accepting overlap tests. Terrain revision travels in existing v4/v6 fields and the optional v5 orbit-link field. Old links lacking that field select sphere-v1.
* Old snapshots preserve old terrain and collision. CITY3 buildings() returns no legacy box geometry; overlap and swept collision use actual compiled source triangles through the runtime.
* The final CITY3 collision ellipsoid Y radius equals clearance(ship); an earlier span times 0.12 version was corrected at the parent's request. X/Z radii remain ship span times 0.55.
* Native F650 pad selection supplies horizontal coordinates. Its rounded source Y can differ by metres from the actual rendered solid floor; landing Y therefore uses the current graded terrain/floor plus ship clearance.
* Source-city autopilot cruises above max compiled city height plus 100 metres, and at least 350 metres. It climbs before horizontal travel when below the required safe height. Old autopilot thresholds are preserved for v1/v2.

## Ground contact fix

Source-city floor triangles can be swept before the terrain-altitude branch reaches zero. Low upward contacts must be classified as ground, otherwise autopilot would brake and hover forever.

The known final classification requires contact normal dot UP greater than 0.9 and contact-bottom height within approximately 0.25 metre of height_at. A ground contact sets the center to contact.position plus normal times 0.05, zeroes velocity/throttle, cancels landing/takeoff/vertical transition and sets landed. Hard ground impact damage is applied once. Wall and roof contacts remove inward velocity, brake and cancel automatic landing; they do not create a rooftop landing protocol.

The added _ground_position(ship) starts at height_at plus clearance. For CITY3 city data it sweeps from one metre above to half a metre below this point, accepts a matching upward solid-floor contact, and returns its center plus 0.05 along the normal. Otherwise it uses the terrain point plus 0.05 UP. Legacy cases return the exact original terrain point. Automatic landing, manual ground impact and touch_down use this helper.

## Separate changes owned by the parent

The parent corrected SourceCityProfile.plane_height to use the exact transformed source X-cross-Z normal, rather than the ideal spherical tangent. The parent also enlarged flat-inner radii to cover actual compiled solid footprints after independent tests found six insufficient old estimates. Actual New Moscow is source model84, not the earlier controlled model89 preview. Two actual model96 ports are underground, explicitly unsupported for new selected-city entry, while legacy revisions remain loadable.

No source function bodies are supplied here because their complete exact text was not retained.
