# Native manual landing transaction

`NativeLandingTrial.prepare(ship, nav, gear, surface, seconds, steering, roll, lift)`
returns four candidate model references only after every owner accepts the same
interval. The host must swap `candidate_ship`, `candidate_nav`, `candidate_gear`
and `candidate_surface` together. Rejected and uncommitted successful preparations
change none of the caller's models or the actual World.

The explicit trial owns a separate NativeSurface. It does not select the old
terrain mesh as a fallback. One actual F576 classification stages original F575,
complete globals and the exact TraceQuery rows consumed by the native provider.
The separate source F574 model84 probe continues to provide the existing
atmosphere/fuel context; it is not a second player classification. The controller
uses the same Navigation/Hyperdrive raw HP and local F1530 stream already used by
fuel and thermal dynamics. No alternate damage formula or HP owner is added.

Order: copy every owner; bind existing raw HP/thrust; advance copied gear and
clock; stage manual movement and original classification; apply original damage
commands to copied Navigation; commit copied raw session and response pose; run
the existing combined fuel/thermal interval once; acknowledge the resulting
phone velocity residual and validate every owner. Pre-impact nozzle commands are
captured before F575 changes the attitude. Thermal changes only velocity/hull;
the explicit Surface anchor carries its velocity delta to the next raw step
without dropping source Q16 low words. Contact destruction retains the existing
caller termination rule: the subsequent fuel/thermal update is skipped on a dead
ship. Parked idle keeps the accepted raw pose/history and advances schedulers
without reclassifying the old hit.

The new Navigation runtime fork shares only its read-only catalogue during
preparation. This controller never queries, generates or selects catalogue
systems. All owned visit, pending, fuel, thermal, HP/RNG and scheduler containers
are private. NativeSurface gravity uses the existing read-only spin helper and
source Physics sample, so it does not advance World spin or ephemeris caches.
Cold restore is still the untrusted validation boundary; these internal forks
do not replace any existing save decoder. All 56 previous Navigation methods
and 73 previous HyperdriveSession methods remain textually unchanged.

Validation:

- `test_native_landing_trial.gd`: 65 checks, 0 failures. Real Flight,
  Navigation HP/RNG/fuel/thermal and Gear owners; controlled staged Surface for
  late failure injection, transaction isolation, fractional HP, dry thrust,
  deterministic retry, terminal contact and scheduler/cold continuation.
- `test_native_landing_trial_integration.gd`: 146 checks, 0 failures. Actual
  FULL_LAYOUT Sol/Earth source record, signed native root, genuine manual
  gravity descent from its separate 50m entry, F576/Trace/provider/F575, shared
  raw HP, F574 atmosphere, fuel/thermal and persisted Gear. Deployed landing
  preserves 100% hull; retracted landing applies exactly source mass100 raw
  to the existing400raw full hull, resulting in75%. Both contact on interval53.
  The original World remains unchanged across every accepted preparation and
  rejected out-of-chart candidate. Strict native cold restore preserves accepted
  pose/history and launches on generation54 with powered lift; a dry positive
  nozzle request retains the park anchor and never teleports or repeats HP.

The literal Float32 render triangle and original integer F1876/F575 contact
remain separately witnessed laws. This Earth landing reports render AGL
approximately -0.168859m at its exact source response; no AGL snap hides that
difference. The work does not claim a universal whole-world source mesh, full
F569/F570 object-bank dispatch, autopilot integration or physical Android testing.
