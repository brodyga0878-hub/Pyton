#!/usr/bin/env python3
"""Native F574 controls for the explicit corrected_model117_bounds_v1 caller.

F1533 and F574 remain the pinned source instructions. The host caller overrides
only parent outer/inner bounds after F1533, before probing model117 from outside.
This fixture is separate from the unmodified-source placement/height fixtures.
"""
from __future__ import annotations

import argparse
import itertools
import json
import math
from pathlib import Path
import re
import struct
import subprocess
import tempfile

import rebuild_ground_surface_native as surface

PROJECT = surface.PROJECT
POLICY = "corrected_model117_bounds_v1"
BOUNDARY_POLICY = "source_exterior_probe_125pct_axes_v1"
SEEDS = [1, 0x12345678]


def controls(resource, original_fixture):
    model = resource["models"]["117"]
    vertices = bytes.fromhex(model["vertices_hex"])
    axes = [struct.unpack_from("<b", vertices, at)[0] for at in [2, 15, 10]]
    zoom = model["scale"] + model["scale2"]
    exterior = max(abs(x) for x in axes) * (1 << zoom) * 5 // 4
    if axes != [14, 23, 71] or exterior != 744488960:
        raise ValueError("Unreviewed original model117 static axes/scale")
    source_parents = {}
    for row in original_fixture["cases"]:
        if row["parent_model"] == 117:
            uid = struct.unpack_from("<I", bytes.fromhex(row["parent_record_hex"]), 4)[0]
            source_parents.setdefault(uid, row["expected"]["initialized_parent_hex"])
    rows = []
    for seed in SEEDS:
        record = bytearray(68)
        struct.pack_into("<I", record, 4, seed)
        struct.pack_into("<H", record, 12, 117)
        parent = bytearray(surface.OBJECT)
        parent[0x86] = 1
        struct.pack_into("<I", parent, 0xa0, seed)
        for axis in range(3):
            struct.pack_into("<I", parent, axis * 16, 0x7fffffff)
        for direction in itertools.product([-1, 0, 1], repeat=3):
            if not any(direction):
                continue
            norm = math.sqrt(sum(x*x for x in direction))
            radial = [round(0x7fffffff*x/norm) for x in direction]
            point = [(exterior*x) >> 31 for x in radial]
            port = bytearray(surface.OBJECT)
            port[0x56] = 1
            port[0x57] = 1
            port[0x86] = 2
            struct.pack_into("<3q", port, 0x3e, *point)
            base = {
                "mode": "height_query", "policy": POLICY, "boundary_policy": BOUNDARY_POLICY,
                "origin": "explicit synthetic UID and outside model84 probe; real F1533 followed by declared parent-bound override and original F574",
                "parent_model": 117, "port_model": 84, "parent_index": 1,
                "parent_uid_u32": seed, "direction_integer": list(direction),
                "radial_q31": [str(x) for x in radial],
                "point_input_raw": [str(x) for x in point],
                "phase_u16": 0, "inclination_u16": 0,
                "parent_record_hex": record.hex(),
                "port_object_input_hex": port.hex(), "parent_object_input_hex": parent.hex(),
                "original_f1533_parent_hex": source_parents[seed],
                "initial_globals": {name: 0 for name, _, _ in surface.GLOBAL_FIELDS},
            }
            for level in [1, 4, 12]:
                rows.append({**base, "graphics_level": level})
    guarded = []
    guard = max(65536, exterior >> 12)
    for base in rows:
        base["probe_kind"] = "unguarded_boundary_control"
        base["probe_inward_guard_raw"] = "0"
        row = dict(base)
        row["probe_kind"] = "corrected_outside_probe"
        row["probe_inward_guard_raw"] = str(guard)
        point = [(int(x)*(exterior-guard)) >> 31 for x in row["radial_q31"]]
        port = bytearray.fromhex(row["port_object_input_hex"])
        struct.pack_into("<3q", port, 0x3e, *point)
        row["point_input_raw"] = [str(x) for x in point]
        row["port_object_input_hex"] = port.hex()
        guarded.append(row)
    return guarded+rows, axes, zoom, exterior


def build(source, data, executable, model_lines, work, exterior):
    at = executable.find(surface.SIN_SIGNATURE)
    if at < 0 or executable.find(surface.SIN_SIGNATURE, at+1) >= 0:
        raise ValueError("Ambiguous original sine table")
    sine = executable[at:at+65536]
    (work / "sine.bin").write_bytes(sine)
    text, hashes, terrain_resources, q = surface.assembly(source, data, executable, work / "sine.bin", model_lines)
    marker = " call FUNC_001533\n add rsp,24\n mov esi,OFFSET FLAT:port\n"
    if text.count(marker) != 1:
        raise ValueError("Ambiguous caller F1533 initialization boundary")
    override = (
        " call FUNC_001533\n add rsp,24\n"
        f" mov DWORD PTR [rbx+0x138],{exterior & 0xffffffff}\n"
        f" mov DWORD PTR [rbx+0x13c],{exterior >> 32}\n"
        " mov DWORD PTR [rbx+0x140],0\n mov DWORD PTR [rbx+0x144],0\n"
        " mov esi,OFFSET FLAT:port\n"
    )
    text = text.replace(marker, override)
    (work / "policy117.s").write_text(text)
    subprocess.run(["as", "--64", str(work / "policy117.s"), "-o", str(work / "policy117.o")], check=True, cwd=work)
    undefined = subprocess.check_output(["nm", "-u", str(work / "policy117.o")], text=True)
    adapter, adapter_metadata = q.unresolved_adapter(undefined, data)
    if executable[0x67038:0x67038+len(surface.ABS_DOS)] != surface.ABS_DOS:
        raise ValueError("Original CRT abs bytes differ")
    adapter = adapter.replace("_abs:\nmov eax,60\nmov edi,97\nsyscall", """_abs:
push rbp
mov rbp,rsp
mov eax,DWORD PTR [rbp+16]
test eax,eax
jge policy_abs_positive
mov edx,eax
neg edx
jmp policy_abs_return
policy_abs_positive:
mov edx,eax
policy_abs_return:
mov eax,edx
pop rbp
ret""")
    adapter_metadata["unreached_function_traps"].remove("_abs")
    trap_codes = {}
    def trap(match):
        code = 100 + len(trap_codes)
        trap_codes[code] = match[1]
        return match[1]+":\nmov eax,60\nmov edi,"+str(code)+"\nsyscall"
    adapter = re.sub(r"((?:FUNC_\d+|_[A-Za-z0-9_]+)):\nmov eax,60\nmov edi,97\nsyscall", trap, adapter)
    (work / "excluded.s").write_text(adapter)
    subprocess.run(["as", "--64", str(work / "excluded.s"), "-o", str(work / "excluded.o")], check=True)
    subprocess.run(["ld", "-m", "elf_x86_64", str(work / "policy117.o"), str(work / "excluded.o"), "-o", str(work / "policy117")], check=True)
    return text, hashes, terrain_resources, adapter_metadata, trap_codes, surface.sha(sine)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path("/workspace/ffe-upstream/jjffe/ffe.asm"))
    parser.add_argument("--executable", type=Path, default=Path("/workspace/ffe-original/FIRSTENC.EXE"))
    parser.add_argument("--work", type=Path)
    args = parser.parse_args()
    source_raw = args.source.read_bytes()
    executable = args.executable.read_bytes()
    if surface.sha(source_raw) != surface.ASM_SHA or surface.sha(executable) != surface.EXE_SHA:
        raise ValueError("Unsupported pinned source/executable")
    original_path = PROJECT / "tests/fixtures/source_ground_surface_native.json"
    resource_path = PROJECT / "data/ffe_ground_collision.json"
    original_bytes = original_path.read_bytes()
    original = json.loads(original_bytes)
    model_data, model_lines = surface.resources(executable)
    if json.loads(resource_path.read_bytes()) != model_data:
        raise ValueError("Frozen model resource differs from EXE extraction")
    rows, axes, zoom, exterior = controls(model_data, original)
    temporary = tempfile.TemporaryDirectory(prefix="ffe-model117-policy-") if args.work is None else None
    work = Path(temporary.name) if temporary else args.work
    work.mkdir(parents=True, exist_ok=True)
    source = source_raw.decode().replace("\r\n", "\n")
    data = args.source.with_name("ffedat.asm").read_text()
    text, hashes, resources, adapter, traps, sine_sha = build(source, data, executable, model_lines, work, exterior)
    ordered = rows + list(reversed(rows))
    payload = b"".join(map(surface.packet, ordered))
    outputs = []
    for _ in range(3):
        result = subprocess.run([str(work / "policy117")], input=payload, capture_output=True, timeout=120)
        if result.returncode != 0:
            raise RuntimeError("Native policy control failed status%d(%s) after%d records" % (result.returncode, traps.get(result.returncode, "native fault"), len(result.stdout)//surface.OUTPUT))
        if len(result.stdout) != len(ordered)*surface.OUTPUT:
            raise ValueError("Incomplete native policy output")
        outputs.append(result.stdout)
    if outputs[0] != outputs[1] or outputs[0] != outputs[2]:
        raise ValueError("Fresh-process outputs differ")
    surface.decode(rows, outputs[0], query=True)
    rejected = 0
    for row in rows:
        original_parent = bytearray.fromhex(row["original_f1533_parent_hex"])
        struct.pack_into("<2q", original_parent, 0x138, exterior, 0)
        if original_parent.hex() != row["expected"]["initialized_parent_hex"]:
            raise ValueError("Caller changed fields beyond declared bound overrides")
        height = row["expected"]["passes"][0]
        if row["probe_kind"] == "corrected_outside_probe":
            if height["collision_kind_u8"] != 255 or height["height_s32"] <= 0 or row["expected"]["terrain_query_calls"] != 1:
                raise ValueError("Guarded exterior probe entered an unreviewed inner/contact path")
            point = [int(x) for x in row["point_input_raw"]]
            radius = math.sqrt(sum(float(x)*x for x in point))-height["height_s32"]
            row["expected"]["caller_derived_surface_radius_raw"] = radius
            row["expected"]["caller_derived_surface_point_raw"] = [str(round(float(int(x))*radius/2147483647.0)) for x in row["radial_q31"]]
        elif height["height_s32"] == -1:
            rejected += 1
            if height["collision_kind_u8"] != 0 or row["expected"]["terrain_query_calls"] != 0:
                raise ValueError("Unguarded boundary rejection branch changed")
        elif height["collision_kind_u8"] != 255 or height["height_s32"] <= 0 or row["expected"]["terrain_query_calls"] != 1:
            raise ValueError("Unguarded boundary control entered an unreviewed path")
        if row["expected"]["initialized_port_hex"] != row["expected"]["port_hex"]:
            raise ValueError("Outside height probe changed the source probe object")
    report = {
        "schema": 1, "revision": "source-model117-surface-policy-native-v1", "policy": POLICY, "boundary_policy": BOUNDARY_POLICY,
        "source_variant": surface.VARIANT, "source_commit": surface.COMMIT,
        "source_sha256": surface.EXE_SHA, "source_assembly_sha256": surface.ASM_SHA,
        "source_data_assembly_sha256": surface.sha(args.source.with_name("ffedat.asm").read_bytes()),
        "scope": "Actual F1533 initialization then explicit caller-only parent bound override, followed by original F574/F575/F576/F579/F582/F581/F1876. This is a corrected outside radial-query policy for non-spherical model117, not the original F1533 bounds or a spherical original surface claim.",
        "static_axes_s8": axes, "static_mesh_zoom": zoom,
        "parent_bound_overrides": {"outer_raw": str(exterior), "inner_raw": "0", "byte_ranges": [[0x138, 0x148]], "formula": "5/4 * max(abs(static axis)) * 2^(descriptor.scale+scale2)"},
        "reference_radius_metres_exact": "5958675/8", "reference_radius_metres": 744834.375,
        "case_count": len(rows), "corrected_probe_case_count": len(rows)//2, "unguarded_boundary_case_count": len(rows)//2,
        "unguarded_boundary_rejection_count": rejected,
        "direction_count_per_uid": 26, "parent_uids_u32": SEEDS, "graphics_levels": [1,4,12], "live_graphics_level": 1,
        "probe_inward_guard_raw": str(max(65536, exterior >> 12)), "probe_inward_guard_formula": "max(65536, reference_radius_raw >> 12)",
        "probe_point_formula": "(radial_q31_component * (exterior_radius_raw-inward_guard_raw)) arithmetic_shift_right 31",
        "caller_surface_formula": "radius = EuclideanNorm(probe_raw)-native_height_s32; point = round(radial_q31*radius/(2^31-1)); declared radial controller approximation, not an original F879 call",
        "fresh_process_runs": 3, "reverse_repeat_count": len(rows),
        "original_source_procedure_hashes": hashes, "original_resources": resources,
        "host_adapter": adapter, "adapted_assembly_sha256": surface.sha(text.encode()), "sine_sha256": sine_sha,
        "native_ordered_output_sha256": surface.sha(outputs[0]),
        "observation_matches_untouched_objects_and_query": True,
        "parent_bank_unchanged": True, "object_canaries_unchanged": True,
        "all_corrected_controls_outside_terrain_kind255": True,
        "input_fixture_sha256": surface.sha(original_bytes), "ground_resource_sha256": surface.sha(resource_path.read_bytes()),
        "cases": rows,
    }
    target = PROJECT / "tests/fixtures/source_model117_surface_policy_native.json"
    target.write_text(json.dumps(report, separators=(",", ":"))+"\n")
    print("SOURCE MODEL117 POLICY NATIVE:", len(rows), "outside F574 queries; 3 fresh processes, reverse, full objects/canaries; work", work)


if __name__ == "__main__":
    main()
