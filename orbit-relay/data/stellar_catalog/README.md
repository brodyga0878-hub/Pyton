# Measured star records: HYG 4.1

This separately licensed data subset contains **4,380 star records excluding Sol**:
all **4,059** valid non-Sol HYG records whose catalog distance is at most 100 light
years, plus **321** more distant records with a nonempty source `proper` name.
It does not add planets, settlements, binary orbits, or fictitious bridge stars.
Sol and its planetary system are supplied by the separate solar-system module.

**Attribution:** HYG Database v4.1, **David Nash / Astronexus**, licensed under
[Creative Commons Attribution-ShareAlike 4.0 International](https://creativecommons.org/licenses/by-sa/4.0/).
The filtered data and coordinate/name adaptations in `scripts/stellar_catalog_data.gd`
remain under that license. `HYG-LICENSE.txt` is the original upstream license notice.
The original runtime/import algorithms are separate project code.

- [Immutable upstream CSV](https://github.com/astronexus/HYG-Database/blob/c7f7f883fe678cc7680169a50ccd7dcc49b060ce/hyg/CURRENT/hygdata_v41.csv)
- [Immutable catalog documentation](https://github.com/astronexus/HYG-Database/blob/c7f7f883fe678cc7680169a50ccd7dcc49b060ce/hyg/README.md)
- [Immutable upstream license](https://github.com/astronexus/HYG-Database/blob/c7f7f883fe678cc7680169a50ccd7dcc49b060ce/hyg/CURRENT/LICENSE)
- [Upstream archive](https://github.com/astronexus/HYG-Database) and [current HYG home](https://codeberg.org/astronexus/hyg)

This is deliberately the verified archived **4.1** snapshot, not a claim to use a
later release. The CSV SHA256 is
`d9f69fd86bbf90a4e4d52b4c5c53eacfa6dfc0bfdef85bfd94f095e0bebe4ebd`.
Its immutable Git revision is `c7f7f883fe678cc7680169a50ccd7dcc49b060ce`.

## Reproduction

Download the exact CSV above, then from the game directory run:

```sh
python3 tools/import_stellar_catalog.py --source /path/to/hygdata_v41.csv
python3 tools/import_stellar_catalog.py --source /path/to/hygdata_v41.csv --check
```

The importer uses Python's standard library, no random inputs, and no network.
It rejects a different input hash. It writes the generated GDScript data table
and `hyg-v41-provenance.json`; no timestamp or local path enters their bytes.
Use `--output-root /some/directory` to regenerate an independent copy.

Rows have ascending HYG primary IDs. There is one star site per record, even when
records are close components of the same physical system. Array index therefore
has a deterministic, frozen relationship to HYG ID. No records are merged by
name or positional proximity. The importer retains raw source identifiers,
RA/Dec, independent distance and Cartesian coordinates, spectral class,
photometry, and source component fields. Other source columns are not silently
reinterpreted as planets or stellar masses.

Names use source proper name, Bayer/Flamsteed, Gliese, HIP, HD, HR, then HYG.
Familiar stars have original Russian display aliases; the source label is still
available in metadata. Repeated source labels gain a Gliese/HIP/HYG qualifier.
The eleven explicitly unofficial secondary names introduced by HYG 4.1 are
flagged; the game does not claim those names are official IAU names.

## Coordinates and limits

The source documents positions at epoch and equinox **J2000.0**, with equatorial
Cartesian coordinates in parsecs: +X at RA 0h/Dec 0, +Y at RA 6h/Dec 0, +Z at the
north celestial pole. We rotate those original `x,y,z` values into a right-handed
Galactic frame, then convert parsecs to light years:

- X points toward Galactic longitude 0°, latitude 0° (the Galactic-center direction).
- Y points toward longitude 90°, latitude 0°, in the Galactic plane.
- Z points toward the north Galactic pole.
- The spatial origin remains **the Sun**, not the Galactic center.

The rotation convention is checked against
[ERFA `eraIcrs2g`](https://github.com/liberfa/erfa/blob/1a8044cde5b7763295d472a6443387239127c6c8/src/icrs2g.c).
No ERFA implementation code is copied; the importer applies the documented
numerical rotation to its source vectors. The conversion is
`parsec/light_year = (648000/pi)*149597870700/(299792458*31557600)`.
The complete matrix and constants are in the provenance JSON.

HYG's J2000 label does not establish subarcsecond ICRS precision; we do not model
that small frame bias. Positions are not propagated to the game's clock.
Full source/computed doubles remain in metadata; the engine's `Vector3` uses
ordinary single-precision rendering/navigation coordinates.

The `dist` and `xyz` columns occasionally differ slightly in HYG. Both are
preserved; coordinates are **not** rescaled to force equality. Values with
`dist >= 100000 pc` indicate missing or dubious parallax and are excluded.
The subset has no catalog error bars and is not a complete modern stellar census.
An RV value of zero can encode missing information; it does not establish that
a star is stationary. The source `lum` is kept as a catalog photometric value,
without claiming a newly measured bolometric luminosity.

Multiple-record associations require matching nonempty `base` and
`comp_primary` source fields. These links, mainly present for Gliese stars, are
incomplete: for example HYG does not group Proxima with Alpha Centauri A/B.
Descriptions report catalog record groups only; they do not assert a complete
physical architecture or generate binary trajectories.

HYG supplies no stellar masses/radii or planetary architecture here. The local
star's radius 220 and gravity parameter 8000 are explicit game reference values,
not astronomical measurements. Metadata leaves physical masses/radii unavailable.
Distant named records are not guaranteed to be connected by the short-jump scan
range; the importer never fills a real gap with invented stars.
