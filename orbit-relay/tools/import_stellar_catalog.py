#!/usr/bin/env python3
"""Reproduce the pinned HYG 4.1 star-record subset; no network or random inputs.

Download the immutable CSV URL in data/stellar_catalog/README.md, then run:
  python3 tools/import_stellar_catalog.py --source /path/to/hygdata_v41.csv
Use --check to compare generated data/provenance without writing anything.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import math
from pathlib import Path
from collections import Counter, defaultdict

REVISION = "c7f7f883fe678cc7680169a50ccd7dcc49b060ce"
SOURCE_SHA256 = "d9f69fd86bbf90a4e4d52b4c5c53eacfa6dfc0bfdef85bfd94f095e0bebe4ebd"
SOURCE_URL = f"https://raw.githubusercontent.com/astronexus/HYG-Database/{REVISION}/hyg/CURRENT/hygdata_v41.csv"
LICENSE_URL = f"https://github.com/astronexus/HYG-Database/blob/{REVISION}/hyg/CURRENT/LICENSE"
PARSEC_TO_LY = 149597870700.0 * (648000.0 / math.pi) / (299792458.0 * 31557600.0)
MAX_NEARBY_LY = 100.0
# ICRS -> Galactic convention, as independently checked against ERFA eraIcrs2g.
# HYG identifies its frame as epoch/equinox J2000; do not claim subarcsecond ICRS accuracy.
ROTATION = (
    (-0.0548755604162154, -0.8734370902348850, -0.4838350155487132),
    (0.4941094278755837, -0.4448296299600112, 0.7469822444972189),
    (-0.8676661490190047, -0.1980763734312015, 0.4559837761750669),
)
COLUMNS = (
    "HYG_ID", "NAME", "LABEL", "PROPER", "BAYER_FLAMSTEED", "GLIESE", "HIP", "HD", "HR",
    "RA_HOURS", "DEC_DEGREES", "DISTANCE_PC", "EQUATORIAL_PC", "GALACTIC_LY", "SPECTRUM",
    "COLOR_INDEX", "APPARENT_MAGNITUDE", "ABSOLUTE_MAGNITUDE", "LUMINOSITY_SOLAR", "COMP",
    "COMP_PRIMARY", "BASE", "GROUP_IDS", "PROPER_MOTION_RA", "PROPER_MOTION_DEC", "RADIAL_VELOCITY",
    "NAME_LOCALIZED", "UNOFFICIAL_COMPANION_NAME", "CONSTELLATION",
)
# Original Russian display aliases only; source labels and identifiers remain intact.
RUSSIAN_NAMES = {
    "Proxima Centauri": "Проксима Центавра", "Rigil Kentaurus": "Альфа Центавра A",
    "Toliman": "Альфа Центавра B", "Barnard's Star": "Звезда Барнарда",
    "Wolf 359": "Вольф 359", "Lalande 21185": "Лаланд 21185", "Sirius": "Сириус A",
    "Ross 154": "Росс 154", "Ross 248": "Росс 248", "Ross 128": "Росс 128",
    "Ross 614": "Росс 614", "Ran": "Эпсилон Эридана (Ран)", "Lacaille 9352": "Лакайль 9352",
    "Lacaille 8760": "Лакайль 8760", "Groombridge 34": "Грумбридж 34 A",
    "Groombridge 1830": "Грумбридж 1830", "Kapteyn's Star": "Звезда Каптейна",
    "Luyten's Star": "Звезда Лейтена", "Van Maanen's Star": "Звезда ван Маанена",
    "Wolf 1061": "Вольф 1061", "Struve 2398 A": "Струве 2398 A", "Struve 2398 B": "Струве 2398 B",
    "Kruger 60": "Крюгер 60 A", "Procyon": "Процион A", "Pollux": "Поллукс",
    "Vega": "Вега", "Altair": "Альтаир", "Fomalhaut": "Фомальгаут", "Arcturus": "Арктур",
    "Capella": "Капелла", "Aldebaran": "Альдебаран", "Regulus": "Регул",
    "Castor": "Кастор A", "Castor B": "Кастор B", "Alpheratz": "Альферац",
    "Caph": "Каф", "Achird": "Ахирд", "Algol": "Алголь", "Hamal": "Хамаль",
    "Mizar": "Мицар", "Alcor": "Алькор", "Alioth": "Алиот", "Merak": "Мерак",
    "Phecda": "Фекда", "Megrez": "Мегрец", "Dubhe": "Дубхе", "Alkaid": "Алькаид",
    "Denebola": "Денебола", "Alphecca": "Альфекка", "Rasalhague": "Рас Альхаге",
    "Polaris": "Полярная звезда", "Betelgeuse": "Бетельгейзе", "Rigel": "Ригель",
    "Deneb": "Денеб", "Spica": "Спика", "Antares": "Антарес", "Canopus": "Канопус",
    "Bellatrix": "Беллатрикс", "Mintaka": "Минтака", "Alnilam": "Альнилам", "Alnitak": "Альнитак",
    "Mirach": "Мирах", "Mirfak": "Мирфак", "Kochab": "Кохаб", "Shaula": "Шаула",
    "Sadr": "Садр", "Scheat": "Шеат", "Markab": "Маркаб", "Enif": "Эниф",
}
# Unambiguous source Gliese component, not a newly inferred astronomical system.
RUSSIAN_GLIESE = {"Gl 244B": "Сириус B", "Gl 280B": "Процион B", "Gl 15B": "Грумбридж 34 B"}
UNOFFICIAL_COMPANIONS = {
    "Revati B", "Cor Caroli B", "Alkalurops B", "Acrab B", "Marsic B", "Dziban B", "Alya B",
    "Albireo B", "Castor B", "Alula Australis B", "Guniibuu B",
}
REQUIRED = {
    "id", "hip", "hd", "hr", "gl", "bf", "proper", "ra", "dec", "dist", "pmra", "pmdec", "rv",
    "mag", "absmag", "spect", "ci", "x", "y", "z", "comp", "comp_primary", "base", "lum", "con",
}


def number(row: dict[str, str], key: str) -> float | None:
    value = row[key].strip()
    if not value:
        return None
    result = float(value)
    if not math.isfinite(result):
        raise ValueError(f"Non-finite {key} in HYG {row['id']}")
    return result


def integer(row: dict[str, str], key: str) -> int:
    return int(row[key]) if row[key].strip() else 0


def galactic(point: list[float]) -> list[float]:
    return [sum(a * b for a, b in zip(axis, point)) * PARSEC_TO_LY for axis in ROTATION]


def label(row: dict[str, str]) -> str:
    for key in ("proper", "bf", "gl"):
        if row[key].strip():
            return " ".join(row[key].split())
    for key, prefix in (("hip", "HIP"), ("hd", "HD"), ("hr", "HR")):
        if row[key].strip():
            return f"{prefix} {integer(row, key)}"
    return f"HYG {integer(row, 'id')}"


def generate(source: bytes) -> dict[str, bytes]:
    actual_sha = hashlib.sha256(source).hexdigest()
    if actual_sha != SOURCE_SHA256:
        raise ValueError(f"Expected pinned HYG 4.1 SHA256 {SOURCE_SHA256}, got {actual_sha}")
    reader = csv.DictReader(io.StringIO(source.decode("utf-8"), newline=""))
    if not REQUIRED.issubset(reader.fieldnames or []):
        raise ValueError("The HYG schema lacks required source fields")
    selected = []
    source_count = 0
    excluded_unknown_distance = 0
    seen = set()
    for row in reader:
        source_count += 1
        ident = integer(row, "id")
        if ident in seen:
            raise ValueError(f"Duplicate HYG ID {ident}")
        seen.add(ident)
        dist = number(row, "dist")
        if ident == 0:
            continue  # Sol is the caller's separate origin and solar-system module.
        if dist is None or not 0.0 < dist < 100000.0:
            excluded_unknown_distance += 1
            continue
        point = [number(row, key) for key in ("x", "y", "z")]
        if any(value is None for value in point):
            continue
        if not 0.0 <= number(row, "ra") < 24.0 or not -90.0 <= number(row, "dec") <= 90.0:
            continue
        if dist * PARSEC_TO_LY <= MAX_NEARBY_LY or row["proper"].strip():
            selected.append(row)
    selected.sort(key=lambda row: integer(row, "id"))
    labels = Counter(label(row) for row in selected)
    groups = defaultdict(list)
    for row in selected:
        if row["base"].strip() and integer(row, "comp_primary"):
            groups[(row["base"].strip(), integer(row, "comp_primary"))].append(integer(row, "id"))
    rows = []
    for row in selected:
        original_label = label(row)
        localized = RUSSIAN_NAMES.get(row["proper"], RUSSIAN_GLIESE.get(row["gl"], ""))
        name = localized or original_label
        if labels[original_label] > 1:
            qualifier = row["gl"].strip() or (f"HIP {row['hip']}" if row["hip"] else f"HYG {row['id']}")
            name += f" · {qualifier}"
        xyz = [number(row, key) for key in ("x", "y", "z")]
        related = groups.get((row["base"].strip(), integer(row, "comp_primary")), [])
        rows.append([
            integer(row, "id"), name, original_label, row["proper"].strip(), row["bf"].strip(), row["gl"].strip(),
            integer(row, "hip"), integer(row, "hd"), integer(row, "hr"), number(row, "ra"), number(row, "dec"),
            number(row, "dist"), xyz, galactic(xyz), row["spect"].strip(), number(row, "ci"), number(row, "mag"),
            number(row, "absmag"), number(row, "lum"), integer(row, "comp"), integer(row, "comp_primary"),
            row["base"].strip(), list(related), number(row, "pmra"), number(row, "pmdec"), number(row, "rv"),
            bool(localized), row["proper"].strip() in UNOFFICIAL_COMPANIONS, row["con"].strip(),
        ])
    if source_count != 119626 or len(rows) != 4380:
        raise ValueError(f"Unexpected pinned catalog count: source={source_count}, selected={len(rows)}")
    near_count = sum(row[COLUMNS.index("DISTANCE_PC")] * PARSEC_TO_LY <= MAX_NEARBY_LY for row in rows)
    gd = [
        "extends RefCounted", "## GENERATED by tools/import_stellar_catalog.py; do not edit rows manually.",
        "## HYG Database v4.1 — David Nash / Astronexus, CC BY-SA 4.0.",
        "## Filtered and transformed data; see data/stellar_catalog/README.md and HYG-LICENSE.txt.",
        f"const COUNT := {len(rows)}", f'const SOURCE_SHA256 := "{SOURCE_SHA256}"',
        f"const PARSEC_TO_LY := {PARSEC_TO_LY!r}",
    ]
    gd += [f"const {column} := {index}" for index, column in enumerate(COLUMNS)]
    gd += ["const ROWS := ["]
    gd += ["\t" + json.dumps(row, ensure_ascii=False, allow_nan=False, separators=(",", ":")) + "," for row in rows]
    gd += ["]", ""]
    generated = "\n".join(gd).encode("utf-8")
    report = {
        "catalog": "HYG Database", "version": "4.1", "author": "David Nash / Astronexus",
        "license": "CC-BY-SA-4.0", "license_url": "https://creativecommons.org/licenses/by-sa/4.0/",
        "source_url": SOURCE_URL, "source_revision": REVISION, "source_sha256": actual_sha,
        "source_license_url": LICENSE_URL, "source_records_including_sol": source_count,
        "selection": "Exclude Sol; require finite source RA/Dec/xyz and 0 < dist < 100000 pc; include every record with dist <= 100 ly or non-empty source proper name.",
        "selected_star_records_excluding_sol": len(rows), "nearby_records_le_100_ly": near_count,
        "additional_farther_proper_named_records": len(rows) - near_count,
        "excluded_non_sol_unknown_or_invalid_distances": excluded_unknown_distance,
        "order_and_identity": "Ascending immutable HYG id; one source record per entry; no positional or name-based merging.",
        "input_epoch_and_equinox": "J2000.0 (as labelled by HYG); positions are not propagated to the game epoch.",
        "coordinate_units": "heliocentric Galactic Cartesian light years; +X l=0,b=0, +Y l=90,b=0, +Z Galactic north",
        "source_xyz_units": "parsec, equatorial J2000 axes: +X RA0, +Y RA6h, +Z north celestial pole",
        "parsec_to_light_year": PARSEC_TO_LY, "conversion_definition": "(648000/pi)*149597870700 / (299792458*31557600)",
        "equatorial_to_galactic_matrix": ROTATION,
        "matrix_convention_reference": "https://github.com/liberfa/erfa/blob/1a8044cde5b7763295d472a6443387239127c6c8/src/icrs2g.c",
        "coordinate_changes": "Rotate original source xyz and multiply by parsec-to-ly; do not rescale xyz to dist or invent missing parallax. Original xyz and independent dist are retained.",
        "name_changes": "Manual Russian display aliases for familiar stars; otherwise proper, Bayer/Flamsteed, Gliese, HIP, HD, HR, then HYG. Duplicate source labels receive a source identifier qualifier.",
        "multiples": "Individual records retained. Related records require identical non-empty HYG base and comp_primary fields. This does not create a binary orbit or claim a complete physical system.",
        "limitations": [
            "This is the pinned historical HYG 4.1 subset, not a complete modern census or Gaia uncertainty model.",
            "HYG distance and xyz occasionally differ slightly; both original values are preserved.",
            "Source uncertainties are unavailable; J2000 to ICRS frame bias is not modelled.",
            "No masses, radii, planets or orbital architecture are supplied or inferred from HYG.",
            "Some source proper names for secondaries are explicitly unofficial HYG chart labels.",
            "A radial velocity value of 0 is not treated as proof of stationarity.",
            "Distant named records are not guaranteed to form a connected short-jump network.",
        ],
        "generated_gd_sha256": hashlib.sha256(generated).hexdigest(),
        "columns": list(COLUMNS),
    }
    return {
        "scripts/stellar_catalog_data.gd": generated,
        "data/stellar_catalog/hyg-v41-provenance.json": (json.dumps(report, ensure_ascii=False, indent=2) + "\n").encode("utf-8"),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--check", action="store_true", help="Compare existing generated files; write nothing")
    args = parser.parse_args()
    outputs = generate(args.source.read_bytes())
    for relative, content in outputs.items():
        path = args.output_root / relative
        if args.check:
            if not path.is_file() or path.read_bytes() != content:
                raise SystemExit(f"Generated output differs: {relative}")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
        print(f"{relative}: {len(content)} bytes, SHA256 {hashlib.sha256(content).hexdigest()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
