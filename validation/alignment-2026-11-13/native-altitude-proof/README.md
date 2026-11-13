# Independent native altitude investigation, 2026-11-13

These files add experiments only. The published 993-case fixture, its generator, original samplers and runtime are unchanged.

`alignment-native-query-probes.json` contains 35 canonical F576 controls (five model120 poses, graphics levels0…6), three fresh native runs and reverse repeats. It also contains150 direct originalF581/F1876 controls with prescribed vector scales3…12 and graphics levels0/1/4. The latter are explicit context experiments; F579 itself chooses canonical scale3 for all five poses. `forced-scale-kernel.s` preserves the original F581/F1876 code, sets its context using actual descriptors and original F1660 truncation, and reads its actual globals. No expected height arithmetic is calculated in Python. The executable, assembly and output SHA256 values are in the JSON. Run `python validation/alignment-2026-11-13/native-altitude-proof/rebuild_native_query_probes.py` from the project to rebuild the archived assemblies into a fresh temporary directory. This read-only reproduction matched both recorded native output hashes.

The common source model is120, UID0x12340000, from the Moon record in the frozen natural-contact fixture. Canonical experiments use real Eagle24 inner5200, body57=1 and body56=parent86, to query an already body-fixed point without an additional frame transform. Eagle has the actual zero-child marker. The F581 previous-altitude result matches the Cobra case because the initial solid query returns before Cobra children. Experiments do not assert physical-SI interpretation for arbitrary raw scales.

| Input pose | Body-fixed raw coordinates | Native previous-altitude, canonical scale3/detail1 |
| --- | --- | ---: |
| continuous sampler first probe | -2033142121, -3584667443, 1540339193 | 541005576 |
| continuous sampler intermediate probe | -1814382072, -3198967880, 1374603274 | 67475960 |
| continuous sampler final point | -1783199833, -3143989945, 1350979139 | -123592 |
| rendered grid height at origin | -1783199125, -3143988506, 1350978525 | -125288 |
| rendered grid height plus9.6m | -1783203560, -3143996326, 1350981885 | -115720 |

Read-only Godot sampling at latitude−0.952346381057215, longitude−2.49323566115386 gives grid height−100764.435707053m and the un-interpolated two-pass sample−100762.789893659m. Their difference is1.646m; removing grid interpolation alone leaves the large signed residual shown above. The first and intermediate sampling poses change with detail level, whereas all three near-surface poses return exactly the same altitude for levels0…6. Prescribed vector scales do change integer results: for the final sample scale4 gives−123648raw and scale12 gives−155648raw. An alignment field must therefore use the actual canonical scale and detail context.

## Source semantics

- F879 (`ffe.asm:64353`) makes exactly two F574 calls. After the second call it recomputes all three position components from saved radial components and the scalar, then copies24bytes to port+0x3E. A position mutation by F575 inside a height query is deliberately overwritten by F879's final copy. Both model120 sample queries above return positive heights, so they do not invoke the solid-contact response anyway.
- The current continuous sampler uses pinned-JJFFE F879's documented SAR3 (7/8 first-height subtraction). Uploaded DOS F879 instead uses SAR4 (15/16). The continuous arbitrary-direction adapter is not a claim that the original discrete F1674 matrix constructor produced these exact coordinates. The numeric experiment establishes that this adapter's final point is not a zero of the original F581 kernel; it does not establish a numeric defect in every original DOS port placement.
- F579 (`ffe.asm:37656`) chooses scale from F1658 plus the descriptor minimum, truncates the point, scales the threshold and applies the parent frame unless body57/body56 selects an already shared frame.
- F581 (`ffe.asm:38317` onward) queries the real terrain, writes signed query height shifted back by context scale to DATA8703/8704 and copies it to DATA8705/8706. If solid, it zeroes current altitude but preserves previous-altitude. The strict solid condition is `(scaled_body_inner >>16) > query_height` (`ffe.asm:38474`). For the actual three ship radii and normal scales this threshold is zero, so the source does not report a new hit merely because an origin is one inner-radius above the zero surface.
- F575 correction uses `(body.inner − previous_altitude) × radial_normal`. Gear state0x9E==FFFF contributes to landing acceptance; it is not an independent9.6m geometry offset in F581.
- F1876 (`ffe.asm:129690` onward) chooses depth from the input radius metric and detail. Query mode initializes detail to graphics_level−1. Render mode can increment it according to observer distance. F1829 (`ffe.asm:113642`) then assigns per-vertex depth from max(1024,vertex.z). Thus source contact and rendered triangles need not be a single frame-independent continuous height function.

## Correction supported by this evidence

Preserve the historical F879 sampler and its frozen checks for port placement. Give the modern surface adapter a distinct policy that brackets and refines the signed F581 contact boundary in the same canonical body-fixed context, rather than declaring a two-pass output an exact zero or adding a constant correction. Any chosen integer root boundary must expose its actual bracket and precision. Above-ground no-hit and accepted landed-state holding remain separate decisions; this investigation does not justify forcing F576 hit at ship clearance.
