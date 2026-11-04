# Recovery notes: original distance units

This is a new preservation note transcribing findings retained in the agent's context. It is NOT an exact restoration of the missing original `docs/ORIGINAL_DISTANCE_UNITS_RU.md` file. No runtime implementation is introduced.

Reviewed assembly source formerly at `/workspace/ffe-upstream/jjffe/ffe.asm`, with FFED3D srctools as secondary hints. Original EXE hash is recorded in `../PROVENANCE.md`.

1. Actual HUD distance formatting was traced through F1100 and F1109, not F1104. Relative Vec64 passes F590/F1658 truncation to13bits, F1466 norm, F1489 packed arithmetic, exponent adjustment`S-15`, and F1496 normalization.
2. The kilometre branch computes `K = SAR32(M*0xd1d0, (29-E)&31)`. `0xd1d0=53712`. These constants were verified in the uploaded executable at byte offsets`0x35ecf` and`0x3639d`.
3. The kilometre output uses two decimal places. The continuous conversion compatible with those rounded source constants is therefore:

`metres_per_raw = 53712*10/2^29 = 16785/16777216 ≈ 0.0010004639625549316`.

`raw_per_kilometre ≈ 999536.2526064939`.

FFED3D's commented `KM_DIST=999539.7368756` is an approximate hint, differing by about3.49ppm; it is not the authoritative formatter derivation. Neither value is a claim that original FFE astronomical sizes equal modern exact SI measurements.

4. The AU branch uses a separate rounded constant`0xeb54=60244` and three decimal places: `raw_per_AU = 2^53*1000/60244 ≈ 149511972225300.3`. The two formatter constants cannot both be treated as one exact modern SI/AU calibration.
5. F579 copies descriptor fields`A=+14`, `B=+18` into physical collision work. F580/F581 static signed-byte vertices ultimately have physical coordinates `v * 2^(A+B)`, subject to original integer truncation/rotation.
6. Descriptor`+2c` outer radius and`+30` inner radius are Q8 values. F1533/F1495 produce `signed16(radius_q8) * 2^(A+B-8)` in original Vec64 units. Descriptor`+1c` draw/frustum radius is a different field.
7. Physical object visual zoom`+7e` affects F1680 rendering, but not F579 collision scaling or F1533's radius construction. It must not be applied blindly to physical model dimensions.
8. The outer radius is not the geoid. F879 starts at `(outer_q8-1)*2^(A+B-8)` and makes TWO real F574 corrections. Replacing that process with the outer bound as a planet sphere is unsupported.
9. Example checked during research: model312 has A12/B0; byte coordinate80 is327680raw, about327.832m with the HUD coefficient. Its Q8 outer radius20625 is330000raw, about330.153m.

Source references retained in read output: F1100 rangeKM around line81261; F1109 around81746; F579 around37656; F879 around64353. Those source files are unavailable in the replacement environment. Full F879 evidence and exact restored generator are in `../docs/ORIGINAL_CITY_PLACEMENT_RU.md` and `../tools/build_city_placement_reference.py`.
