#!/usr/bin/env python3
"""Extract original FFE map colours/labels; optionally execute F853 overview controls.

Numeric tables must match unique bytes in the user-supplied executable.
The optional oracle executes original instructions using the existing host-native
sector harness. It changes only the F853 caller's third argument to nine scales;
it does not use a Python implementation of density as an expected answer.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[1]
EXE_SHA = "d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
ASM_SHA = "d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a"
DATA_SHA = "34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850"
UPSTREAM_COMMIT = "7e540341d4e09aa3c92877b87d49e7f2c143ad8d"


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def emit(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exe", type=Path, default=Path("/workspace/ffe-original/FIRSTENC.EXE"))
    parser.add_argument("--asm", type=Path, default=Path("/workspace/ffe-upstream/jjffe/ffe.asm"))
    parser.add_argument("--data", type=Path, default=Path("/workspace/ffe-upstream/jjffe/ffedat.asm"))
    parser.add_argument("--native", action="store_true")
    args = parser.parse_args()
    executable = args.exe.read_bytes()
    asm_bytes = args.asm.read_bytes()
    data_bytes = args.data.read_bytes()
    assert (sha(executable), sha(asm_bytes), sha(data_bytes)) == (EXE_SHA, ASM_SHA, DATA_SHA), "Pinned source mismatch"
    spec = importlib.util.spec_from_file_location("galaxy_native_harness", PROJECT / "tools/rebuild_source_galaxy_native.py")
    harness = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(harness)
    data_source = data_bytes.decode()
    tables = {}
    provenance = []
    for first, last in [(6821, 6822), (7769, 7770), (6812, 6816)]:
        raw, labels = harness.numeric_block(data_source, first, last)
        offset = executable.find(raw)
        assert offset >= 0 and executable.find(raw, offset + 1) < 0, f"Missing or ambiguous table{first}"
        tables[first] = raw
        provenance.append({"first_label": first, "exclusive_end_label": last, "executable_offset": offset,
                           "bytes": len(raw), "sha256": sha(raw), "matches_source_bytes": True})
    palette = list(struct.unpack("<64I", tables[6821]))
    rgb6 = [list(tables[7769][i * 3:i * 3 + 3]) for i in range(16)]
    assert palette[0] == 0 and palette[-1] == 15 and all(0 <= v <= 15 for v in palette)
    assert rgb6 == [[4 * i] * 3 for i in range(16)]
    names = {0x84A8: ("Major Arm", "Главный рукав"), 0x84A9: ("Perseus Arm", "Рукав Персея"),
             0x84AA: ("Intermediate Arm", "Промежуточный рукав"), 0x84AB: ("Norma Arm", "Рукав Наугольника"),
             0x84AC: ("Pleiades", "Плеяды"), 0x84AD: ("Dumbell Nebula", "Туманность Гантель")}
    landmarks = []
    for limit, x, y, code in struct.iter_unpack("<4i", tables[6812]):
        if limit == 0:
            assert (x, y, code) == (0, 0, 0)
            break
        row = {"visible_above_scale": limit, "sector_raw": [x, y], "ffcode": code}
        if code in names:
            row.update(name_en=names[code][0], name_ru=names[code][1])
        landmarks.append(row)
    value = {"schema": 1, "source_sha256": EXE_SHA, "source_assembly_sha256": ASM_SHA,
             "source_data_sha256": DATA_SHA, "source_commit": UPSTREAM_COMMIT,
             "scope": "Exact original overview density-to-palette indices, low grayscale palette and F846 landmark records; no full graphical-renderer claim.",
             "source_blocks": provenance, "display_sector_offset_raw": [0x1718, 0x1524],
             "source_overview_pixels": [320, 158], "overview_scale_min": 1, "overview_scale_max": 255,
             "overview_density_ignores_handcrafted_count_override": True,
             "overview_density_scaling": "F853 scale1..15 uses factor65535-(((16-scale)*random_multiplier)>>5); scale16..255 returns the bilinear field directly. Both paths skip handmade sector count overrides.",
             "overview_palette_indices": palette, "overview_palette_rgb6": rgb6,
             "overview_rgb_policy": "sdl_component_shift_left2",
             "density_palette_indices": palette, "low_palette_rgb6": rgb6,
             "low_palette_rgb8_nominal_sdl_shift2": [[v << 2 for v in row] for row in rgb6],
             "low_palette_rgb8_screenshot_bit_replication": [[(v << 2) | (v >> 4) for v in row] for row in rgb6],
             "palette_policy": "Nominal SDL VideoSetPalValue with identity gamma uses RGB6<<2. Screenshot F1448 uses bit replication. Gamma/display calibration is not inferred.",
             "landmarks": landmarks, "landmark_name_policy": "Only six literal arm/nebula names decoded; other FF codes must use the original system/name provider, not guessed labels."}
    output = PROJECT / "data/ffe_galactic_map.json"
    emit(output, value)
    print(f"Exact map resource: {len(palette)} palette entries, {len(landmarks)} landmarks, all3 blocks unique in verified EXE")
    if not args.native:
        return
    resource = harness.resource(data_source, executable)
    rows = harness.cases(resource)
    assembly, hashes = harness.assembly(asm_bytes.decode(), resource)
    old = "positions_done:\n push 0\n mov eax,DWORD PTR [input+4]"
    assert assembly.count(old) == 1

    def execute(path: Path, items: list[dict]) -> list[bytes]:
        result = subprocess.run([str(path)], input=b"".join(harness.packet(row) for row in items),
                                stdout=subprocess.PIPE, check=True, timeout=30)
        assert len(result.stdout) == len(items) * harness.OUTPUT
        return [result.stdout[i * harness.OUTPUT:(i + 1) * harness.OUTPUT] for i in range(len(items))]

    modes = [1, 2, 4, 8, 15, 16, 17, 64, 255]
    all_cases = []
    assembly_hashes = {}
    output_hashes = {}
    with tempfile.TemporaryDirectory(prefix="ffe-overview-density-", dir="/workspace") as directory:
        work = Path(directory)
        for mode in modes:
            adapted = assembly.replace(old, f"positions_done:\n push {mode}\n mov eax,DWORD PTR [input+4]")
            (work / "oracle.s").write_text(adapted)
            subprocess.run(["as", "--64", "-o", str(work / "oracle.o"), str(work / "oracle.s")], check=True)
            subprocess.run(["ld", "-o", str(work / "oracle"), str(work / "oracle.o")], check=True)
            expected = execute(work / "oracle", rows)
            for _ in range(2):
                assert execute(work / "oracle", rows) == expected
            assert execute(work / "oracle", list(reversed(rows))) == list(reversed(expected))
            assembly_hashes[str(mode)] = sha(adapted.encode())
            output_hashes[str(mode)] = sha(b"".join(expected))
            for row, raw in zip(rows, expected):
                assert struct.unpack_from("<I", raw, harness.OUTPUT - 4)[0] == 1
                result = struct.unpack_from("<I", raw, harness.OUTPUT - 8)[0]
                all_cases.append({"x": row["x"], "y": row["y"], "scale": mode, "result": result,
                                  "group": row["group"]})
    fixture = {"schema": 1, "source_sha256": EXE_SHA, "source_assembly_sha256": ASM_SHA,
               "source_data_sha256": DATA_SHA, "source_commit": UPSTREAM_COMMIT,
               "scope": "Original F853 with nine actual overview scale values, using existing source F841/F856/F861 harness with rendering disabled. Expectations are actual host-native instruction outputs, not a Python density implementation. Scale1..15 fades the random-density multiplier; scale16..255 returns the bilinear field directly.",
               "source_procedure_hashes": hashes, "adapted_assembly_sha256_by_scale": assembly_hashes,
               "native_ordered_output_sha256_by_scale": output_hashes, "fresh_process_runs_per_scale": 3,
               "reverse_repeat_count": len(all_cases), "scales": modes, "canaries_unchanged": True,
               "runtime_resource_sha256": sha(output.read_bytes()), "case_count": len(all_cases), "cases": all_cases}
    emit(PROJECT / "tests/fixtures/source_galactic_map_native.json", fixture)
    print(f"Original overview density native: {len(all_cases)} cases,3 fresh processes/reverse per scale agree")


if __name__ == "__main__":
    main()
