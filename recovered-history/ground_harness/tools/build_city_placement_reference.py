#!/usr/bin/env python3
"""Original F879 two-pass city placement through real F574/F581/F1876 terrain.

This host-only control keeps actual model radii, vertices, collision streams and
UIDs. It compares the JJFFE SAR3 correction with a separately labelled SAR4
variant matching the verified local instruction in the uploaded executable.
It does not claim all reviewed JJFFE procedures are binary-identical to that EXE.
"""
import argparse
import hashlib
import json
import re
import struct
import subprocess
import tempfile
from pathlib import Path

import build_terrain_query_reference as query
from build_ground_reference import SIN_SIGNATURE
from build_ground_pads_reference import matrix_for_angles, signed
from build_terrain_provider_reference import uid_representatives
from extract_ship_registry import Image

EXTRA = [571, 574, 575, 576, 579, 581, 582, 583, 879, 1332, 1333, 1334, 1338,
         1341, 1466, 1495, 1501, 1502, 1503, 1504, 1519, 1520, 1522, 1523,
         1532, 1533, 1538, 1552, 1657, 1658, 1660, 1664, 1669, 1670, 1674, 1914]
OUTPUT_BYTES = 512

START = r"""
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 mov esi,OFFSET FLAT:input
 add rsi,r8
 mov edx,28
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,28
 jne read_more
 xor eax,eax
 mov edi,OFFSET FLAT:pool
 mov ecx,10000
 rep stosd
 mov edi,OFFSET FLAT:output
 mov ecx,128
 rep stosd
 mov DWORD PTR [pass_count],0
 mov DWORD PTR [query_count],0
 mov DWORD PTR [repair_count],0
 mov BYTE PTR [parent+0x86],1
 mov eax,DWORD PTR [input]
 push rax
 push OFFSET FLAT:template
 push OFFSET FLAT:parent
 call FUNC_001533
 add rsp,24
 mov BYTE PTR [parent+0x86],1
 mov eax,DWORD PTR [input+4]
 mov DWORD PTR [parent+0xa0],eax
 mov BYTE PTR [city+0x86],2
 mov eax,DWORD PTR [input+8]
 push rax
 push OFFSET FLAT:parent
 push OFFSET FLAT:city
 call FUNC_001533
 add rsp,24
 mov BYTE PTR [city+0x86],2
 mov BYTE PTR [city+0x56],1
 mov BYTE PTR [city+0x57],1
 mov BYTE PTR [city+0x87],1
 or BYTE PTR [city+0x14c],0x30
 cmp DWORD PTR [input+8],81
 jl ground_flags_ready
 cmp DWORD PTR [input+8],90
 jg ground_flags_ready
 or BYTE PTR [city+0x14c],0x40
ground_flags_ready:
 mov DWORD PTR [city+0xc2],0
 mov eax,DWORD PTR [input+24]
 mov DWORD PTR [city+0xa0],eax
 mov eax,DWORD PTR [input+20]
 mov DWORD PTR [DATA_008812],eax
 mov esi,OFFSET FLAT:parent+0x138
 mov edi,OFFSET FLAT:output+60
 mov ecx,4
 rep movsd
 mov esi,OFFSET FLAT:city+0x138
 mov edi,OFFSET FLAT:output+76
 mov ecx,4
 rep movsd
 push OFFSET FLAT:pool
 mov eax,DWORD PTR [input+16]
 push rax
 mov eax,DWORD PTR [input+12]
 push rax
 push OFFSET FLAT:city
 call FUNC_000879
 add rsp,32
 mov esi,OFFSET FLAT:city
 mov edi,OFFSET FLAT:output
 mov ecx,9
 rep movsd
 mov esi,OFFSET FLAT:city+0x3e
 mov edi,OFFSET FLAT:output+36
 mov ecx,6
 rep movsd
 mov eax,DWORD PTR [pass_count]
 mov DWORD PTR [output+92],eax
 mov eax,DWORD PTR [query_count]
 mov DWORD PTR [output+96],eax
 mov eax,DWORD PTR [repair_count]
 mov DWORD PTR [output+508],eax
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,512
 syscall
 jmp next_case
finished:
 mov eax,60
 xor edi,edi
 syscall
FUNC_000574:
 push rbp
 mov rbp,rsp
 push rbx
 push rsi
 push rdi
 mov eax,DWORD PTR [pass_count]
 cmp eax,2
 jge unexpected_path
 imul eax,200
 lea ebx,[rax+output+100]
 inc DWORD PTR [pass_count]
 mov esi,DWORD PTR [rbp+24]
 mov edi,ebx
 mov ecx,6
 rep movsd
 mov esi,OFFSET FLAT:city
 lea edi,[rbx+120]
 mov ecx,9
 rep movsd
 mov eax,DWORD PTR [query_count]
 mov DWORD PTR [ebx+36],eax
 push QWORD PTR [rbp+40]
 push QWORD PTR [rbp+32]
 push QWORD PTR [rbp+24]
 push QWORD PTR [rbp+16]
 call OriginalClearance
 add rsp,32
 push rax
 mov eax,DWORD PTR [rbp+16]
 mov eax,DWORD PTR [eax]
 mov DWORD PTR [ebx+24],eax
 mov eax,DWORD PTR [DATA_008703]
 mov DWORD PTR [ebx+28],eax
 mov eax,DWORD PTR [DATA_008704]
 mov DWORD PTR [ebx+32],eax
 mov eax,DWORD PTR [query_count]
 mov DWORD PTR [ebx+40],eax
 mov eax,DWORD PTR [DATA_009283]
 mov DWORD PTR [ebx+104],eax
 movzx eax,BYTE PTR [DATA_008707]
 mov DWORD PTR [ebx+108],eax
 mov eax,DWORD PTR [DATA_009284]
 mov DWORD PTR [ebx+112],eax
 mov eax,DWORD PTR [DATA_009269]
 mov DWORD PTR [ebx+116],eax
 mov esi,OFFSET FLAT:city
 lea edi,[rbx+156]
 mov ecx,9
 rep movsd
 pop rax
 pop rdi
 pop rsi
 pop rbx
 pop rbp
 ret
FUNC_001876:
 push rax
 push rcx
 push rsi
 push rdi
 inc DWORD PTR [query_count]
 mov eax,DWORD PTR [pass_count]
 dec eax
 imul eax,200
 lea edi,[rax+output+100+44]
 mov esi,DWORD PTR [rsp+32+56]
 mov ecx,9
 rep movsd
 mov esi,DWORD PTR [rsp+32+48]
 mov ecx,3
 rep movsd
 mov eax,DWORD PTR [rsp+32+64]
 mov DWORD PTR [edi],eax
 mov eax,DWORD PTR [rsp+32+16]
 mov DWORD PTR [edi+4],eax
 pop rdi
 pop rsi
 pop rcx
 pop rax
 jmp OriginalTerrainQuery
FUNC_001520:
 inc DWORD PTR [repair_count]
 jmp OriginalMatrixRepair
_abs:
 mov eax,DWORD PTR [rsp+8]
 cdq
 xor eax,edx
 sub eax,edx
 ret
_memcpy:
 push rbp
 mov rbp,rsp
 push rsi
 push rdi
 mov edi,DWORD PTR [rbp+16]
 mov esi,DWORD PTR [rbp+24]
 mov ecx,DWORD PTR [rbp+32]
 mov eax,edi
 rep movsb
 pop rdi
 pop rsi
 pop rbp
 ret
unexpected_path:
 mov eax,60
 mov edi,98
 syscall
"""


def model_resources(executable, model_ids):
    image = Image(executable)
    metadata = {}
    assembly = [".section .data", "DATA_007754: .long FUNC_001532", "DATA_007755: .long FUNC_001533",
                "DATA_007756: .long FUNC_001538", "DATA_007734: .long FUNC_001495",
                "DATA_007719: .long FUNC_001520", "DATA_007737: .long FUNC_001522",
                "DATA_007738: .long FUNC_001502", "DATA_004681:"]
    for model in range(max(model_ids) + 1):
        assembly.append(f".long descriptor_{model}" if model in model_ids else ".long unexpected_path")
    for model in model_ids:
        descriptor = image.pointer(0xba8fc + model * 4, 68)
        raw = executable[descriptor:descriptor + 68]
        fields = struct.unpack("<17I", raw)
        if fields[14] != 0:
            raise ValueError("This city/planet control requires the actual no-vessel-spec descriptors")
        vertices = image.offset(fields[1], fields[2] // 2 * 6)
        collision = image.offset(fields[13], 1)
        if not collision < descriptor or descriptor - collision > 4096:
            raise ValueError("Unbounded original city/planet collision stream")
        # Preserve the preceding sample-list terminator used by F576 as well as
        # the complete stream, including the post-terrain 50 80 00 exit record.
        collision_raw = executable[collision - 2:descriptor]
        if model in list(range(81, 91)) + [96] and collision_raw[:2] != b"\0\0":
            raise ValueError("Unexpected original city extra-probe suffix")
        vertex_raw = executable[vertices:vertices + fields[2] // 2 * 6]
        normal_raw = b""
        if fields[3] and fields[4] > 2:
            normal_at = image.offset(fields[3], (fields[4] // 2 - 1) * 6)
            normal_raw = executable[normal_at:normal_at + (fields[4] // 2 - 1) * 6]
        assembly.extend([f"vertices_{model}:", ".byte " + ",".join(str(v) for v in vertex_raw),
                         f"normals_{model}:", ".byte " + ",".join(str(v) for v in normal_raw or b"\0"),
                         f"collision_prefix_{model}:", ".byte " + ",".join(str(v) for v in collision_raw[:2]),
                         f"collision_{model}:", ".byte " + ",".join(str(v) for v in collision_raw[2:]), f"descriptor_{model}:"])
        for index, value in enumerate(fields):
            replacement = {1: f"vertices_{model}", 3: f"normals_{model}", 13: f"collision_{model}"}.get(index)
            assembly.append(".long " + (replacement or str(value)))
        metadata[str(model)] = {"descriptor_offset": hex(descriptor), "descriptor_hex": raw.hex(),
                                "descriptor_sha256": hashlib.sha256(raw).hexdigest(),
                                "vertex_offset": hex(vertices), "vertex_hex": vertex_raw.hex(),
                                "collision_stream_offset": hex(collision), "collision_prefix_and_stream_hex": collision_raw.hex(),
                                "collision_prefix_and_stream_sha256": hashlib.sha256(collision_raw).hexdigest()}
    return assembly, metadata


def build(source, data, executable, model_ids, variant):
    if variant == "archive_local_sar4":
        start = source.index("FUNC_000879:")
        end = source.index("FUNC_000880:", start)
        block = source[start:end]
        if block.count("\tsar eax,0x3") != 1:
            raise ValueError("Unexpected JJFFE F879 correction instruction")
        source = source[:start] + block.replace("\tsar eax,0x3", "\tsar eax,0x4") + source[end:]
    old_numbers, old_frames = query.NUMBERS, query.WIDENED_FRAMES
    try:
        query.NUMBERS = list(dict.fromkeys(old_numbers + EXTRA))
        query.WIDENED_FRAMES = old_frames + [582, 1495, 1669, 1670]
        hashes = query.function_hashes(source)
        assembly, resources = query.adapt_assembly(source, data, executable)
    finally:
        query.NUMBERS, query.WIDENED_FRAMES = old_numbers, old_frames
    assembly = assembly.replace("FUNC_000574:", "OriginalClearance:").replace("FUNC_001876:", "OriginalTerrainQuery:")
    assembly = assembly.replace("FUNC_001520:", "OriginalMatrixRepair:")
    models_assembly, models = model_resources(executable, model_ids)
    template = query.byte_block(query.data_block(data, 7134))
    at = executable.find(template)
    if len(template) != 340 or at < 0:
        raise ValueError("Original object template does not match uploaded executable")
    table_at = executable.find(SIN_SIGNATURE)
    sine_raw = executable[table_at:table_at + 65536]
    if table_at < 0 or len(sine_raw) != 65536:
        raise ValueError("Missing original sine table")
    model_data = "\n".join(models_assembly) + "\ntemplate:\n.byte " + ",".join(str(v) for v in template)
    masses = query.byte_block(query.data_block(data, 7210))
    if executable.find(masses) < 0:
        raise ValueError("Original auxiliary mass table differs from executable")
    model_data += "\nDATA_007210:\n.byte " + ",".join(str(v) for v in masses)
    for number in [7635, 7636]:
        zero = query.byte_block(query.data_block(data, number))
        if zero != b"\0" * 4:
            raise ValueError("Unexpected original Int64Abs zero constant")
        model_data += f"\nDATA_{number:06d}: .long 0"
    model_data += "\nDATA_007975:\n" + "\n".join(".long " + str(v) for v in struct.unpack("<16384i", sine_raw))
    begin, end = assembly.index("_start:"), assembly.index(".section .bss", assembly.index("_start:"))
    assembly = assembly[:begin] + START + "\n" + model_data + "\n" + assembly[end:]
    assembly = assembly.replace("input: .zero 56", "input: .zero 28")
    assembly = assembly.replace("output: .zero 24", "output: .zero 512\npool: .zero 40000\n.set parent,pool+0x74+338\n.set city,pool+0x74+676\npass_count: .zero 4\nquery_count: .zero 4\nrepair_count: .zero 4")
    return assembly, hashes, {"terrain": resources, "models": models, "template_offset": hex(at),
                              "template_sha256": hashlib.sha256(template).hexdigest(),
                              "sine_table_offset": hex(table_at), "sine_table_sha256": hashlib.sha256(sine_raw).hexdigest()}


def controls(project, model_ids):
    handcrafted = json.loads((project / "data/ffe_handcrafted_records.json").read_text())["records"]
    base = 0
    cases = []
    for slot, row in sorted(handcrafted.items(), key=lambda pair: int(pair[0])):
        raw = bytes.fromhex(row["record_hex"])
        parent_index = struct.unpack_from("<H", raw, 8)[0]
        if parent_index == 0:
            base = int(slot)
        if row["constructor"] != 874:
            continue
        parent = handcrafted[str(base + parent_index - 1)]
        if parent["model_index"] not in model_ids:
            continue
        cases.append({"origin": "original_handcrafted_city", "name_en": row["name_en"], "city_record_slot": int(slot),
                      "source_system_first_slot": base, "parent_record_slot": base + parent_index - 1,
                      "city_record_hex": row["record_hex"], "parent_record_hex": parent["record_hex"],
                      "parent_name_en": parent["name_en"], "parent_model_index": parent["model_index"],
                      "parent_uid_u32": parent["seed_u32"], "city_model_index": row["model_index"], "city_uid_u32": row["seed_u32"],
                      "ground_phase_u16": struct.unpack_from("<H", raw, 18)[0], "ground_inclination_u16": struct.unpack_from("<H", raw, 34)[0],
                      "graphics_level_raw": 1})
    representatives = uid_representatives(project)
    for model in model_ids:
        if model not in representatives:
            continue
        for phase, inclination in [(0, 0), (16384, 0), (0, 16384), (0, 49152), (19355, 5221), (65535, 1)]:
            for detail in [1, 12]:
                cases.append({"origin": "explicit_coordinate_and_model_probe", "parent_model_index": model,
                              "parent_uid_u32": representatives[model]["seed"], "parent_uid_provenance": representatives[model],
                              "city_model_index": 84, "city_uid_u32": 0x12345678,
                              "ground_phase_u16": phase, "ground_inclination_u16": inclination, "graphics_level_raw": detail})
        for city in [81, 82, 83, 85, 86, 87, 88, 89, 90, 96]:
            cases.append({"origin": "explicit_city_shape_probe", "parent_model_index": model,
                          "parent_uid_u32": representatives[model]["seed"], "parent_uid_provenance": representatives[model],
                          "city_model_index": city, "city_uid_u32": 0x12345678,
                          "ground_phase_u16": 19355, "ground_inclination_u16": 5221, "graphics_level_raw": 1})
    if not cases:
        raise ValueError("No original city placement contexts selected")
    return cases


def decode(raw):
    def ints(offset, count):
        return list(struct.unpack_from("<" + "i" * count, raw, offset))
    result = {"matrix_q31": ints(0, 9), "position_vec64_raw": list(struct.unpack_from("<3q", raw, 36)),
              "parent_outer_raw_i64": struct.unpack_from("<q", raw, 60)[0], "parent_inner_raw_i64": struct.unpack_from("<q", raw, 68)[0],
              "city_outer_raw_i64": struct.unpack_from("<q", raw, 76)[0], "city_inner_raw_i64": struct.unpack_from("<q", raw, 84)[0],
              "clearance_calls": ints(92, 1)[0], "terrain_query_calls": ints(96, 1)[0], "matrix_repair_calls": ints(508, 1)[0], "passes": []}
    for index in range(2):
        at = 100 + index * 200
        result["passes"].append({"input_position_vec64_raw": list(struct.unpack_from("<3q", raw, at)),
                                 "clearance_i32": ints(at + 24, 1)[0], "altitude_raw_i64": struct.unpack_from("<q", raw, at + 28)[0],
                                 "query_calls_before": ints(at + 36, 1)[0], "query_calls_after": ints(at + 40, 1)[0],
                                 "query_matrix_raw": ints(at + 44, 9), "query_center_raw": ints(at + 80, 3),
                                 "query_style_raw": ints(at + 92, 1)[0], "query_limit_raw": ints(at + 96, 1)[0],
                                 "intersection_raw": ints(at + 104, 1)[0], "collision_mode_raw": ints(at + 108, 1)[0],
                                 "pending_query_flag": ints(at + 112, 1)[0], "depth_control_raw": ints(at + 116, 1)[0],
                                 "matrix_before_q31": ints(at + 120, 9), "matrix_after_q31": ints(at + 156, 9)})
    return result


def verify_results(cases, results, resources, variant, sine):
    """Independent F879 control flow using observed, unmodified F574 outputs.

    This verifies matrix/radius arithmetic and host adaptation. Terrain heights
    themselves remain actual outputs of the complete original collision/query
    chain; the portable terrain implementation is not used as an oracle here.
    """
    def shifted_product(direction, radius, exponent):
        value = signed(direction * (radius & 0xffffffff), 64)
        return signed(value << exponent, 64) if exponent >= 0 else value >> (-exponent)

    def point(direction, radius, exponent):
        return [shifted_product(v, radius, exponent - 31) for v in direction]

    for case, result in zip(cases, results):
        parent = bytes.fromhex(resources["models"][str(case["parent_model_index"])]["descriptor_hex"])
        city = bytes.fromhex(resources["models"][str(case["city_model_index"])]["descriptor_hex"])
        fields = struct.unpack("<17I", parent)
        city_fields = struct.unpack("<17I", city)
        zoom = signed(fields[5] + fields[6])
        matrix = matrix_for_angles(case["ground_phase_u16"], case["ground_inclination_u16"], sine)
        radial = matrix[3:6]
        exponent = signed(zoom - 8)
        radius = signed(fields[11] - 1)
        first = result["passes"][0]
        if first["input_position_vec64_raw"] != point(radial, radius, exponent):
            raise ValueError("Original F879 initial outer-minus-one probe differs from scalar trace")
        for field, descriptor, item_zoom in [("parent", fields, zoom), ("city", city_fields, city_fields[5] + city_fields[6])]:
            for suffix, offset in [("outer", 11), ("inner", 12)]:
                physical = signed(descriptor[offset], 16)
                expected = physical << (item_zoom - 8) if item_zoom >= 8 else physical >> (8 - item_zoom)
                if result[f"{field}_{suffix}_raw_i64"] != expected:
                    raise ValueError("Original F1533/F1495 physical object radius differs from scalar trace")
        if result["clearance_calls"] != 2 or result["terrain_query_calls"] != 2 or result["matrix_repair_calls"] != 0:
            raise ValueError("Original city placement reached an unreviewed collision side-effect path")
        for pass_ in result["passes"]:
            if pass_["clearance_i32"] <= 0 or pass_["clearance_i32"] != pass_["altitude_raw_i64"]:
                raise ValueError("Original F574 returned an invalid/nonpositive placement clearance")
            if pass_["query_calls_after"] - pass_["query_calls_before"] != 1 or pass_["pending_query_flag"] != 0:
                raise ValueError("Original F574 terrain query did not run once and finish")
            if pass_["collision_mode_raw"] != 255:
                raise ValueError("Original F574 placement probe entered an unreviewed penetration mode")
            if pass_["matrix_before_q31"] != matrix or pass_["matrix_after_q31"] != matrix:
                raise ValueError("Original collision path changed the F1674 city matrix")
        amount = first["clearance_i32"]
        amount = signed(amount - (amount >> (3 if variant == "jjffe_sar3" else 4)))
        if exponent < 0:
            radius = signed(radius - signed(amount << ((-exponent) & 31)))
        elif exponent < 16:
            radius = signed(signed(radius << (exponent & 31)) - amount)
            exponent = 0
        else:
            exponent = signed(exponent - 16)
            radius = signed(signed(radius << 16) - (amount >> (exponent & 31)))
        second = result["passes"][1]
        if second["input_position_vec64_raw"] != point(radial, radius, exponent):
            raise ValueError("Original F879 margin-adjusted second probe differs from scalar trace")
        amount = second["clearance_i32"]
        radius = signed(radius - (signed(amount << ((-exponent) & 31)) if exponent < 0 else amount >> (exponent & 31)))
        if result["position_vec64_raw"] != point(radial, radius, exponent) or result["matrix_q31"] != matrix:
            raise ValueError("Original F879 final city placement differs from independent scalar trace")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("executable", type=Path)
    parser.add_argument("--project", type=Path, default=Path(__file__).parents[1])
    parser.add_argument("--inputs-project", type=Path, default=Path(__file__).parents[1])
    parser.add_argument("--model-ids", default=",".join(str(v) for v in range(118, 134)))
    parser.add_argument("--fixture-name", default="city_placement_reference.json")
    args = parser.parse_args()
    source = args.source.read_text()
    data = args.source.with_name("ffedat.asm").read_text()
    executable = args.executable.read_bytes()
    Image(executable)
    pattern = bytes.fromhex("8b45f8c1f8042945f8")
    archive_at = executable.find(pattern)
    if archive_at != 0x2aa4b or executable.find(pattern, archive_at + 1) >= 0:
        raise ValueError("Archived F879 local SAR4 instruction has not been verified")
    models = [int(word, 0) for word in args.model_ids.split(",")]
    cases = controls(args.inputs_project, models)
    all_models = sorted(set(models + [case["city_model_index"] for case in cases]))
    ordered = cases + list(reversed(cases))
    payload = b"".join(struct.pack("<7I", row["parent_model_index"], row["parent_uid_u32"], row["city_model_index"],
                                    row["ground_phase_u16"], row["ground_inclination_u16"], row["graphics_level_raw"], row["city_uid_u32"]) for row in ordered)
    variants = {}
    sine_at = executable.find(SIN_SIGNATURE)
    sine = list(struct.unpack_from("<16384i", executable, sine_at))
    for variant in ["jjffe_sar3", "archive_local_sar4"]:
        assembly, hashes, resources = build(source, data, executable, all_models, variant)
        with tempfile.TemporaryDirectory(prefix="ffe-city-placement-") as directory:
            work = Path(directory)
            (work / "placement.s").write_text(assembly)
            subprocess.run(["as", "--64", str(work / "placement.s"), "-o", str(work / "placement.o")], check=True)
            undefined = subprocess.check_output(["nm", "-u", str(work / "placement.o")], text=True)
            adapter, adapters = query.unresolved_adapter(undefined, data)
            (work / "excluded.s").write_text(adapter)
            subprocess.run(["as", "--64", str(work / "excluded.s"), "-o", str(work / "excluded.o")], check=True)
            subprocess.run(["ld", "-m", "elf_x86_64", str(work / "placement.o"), str(work / "excluded.o"), "-o", str(work / "placement")], check=True)
            output = subprocess.run([str(work / "placement")], input=payload, capture_output=True, timeout=30)
            if output.returncode != 0:
                raise RuntimeError(f"Original {variant} city placement status{output.returncode}, complete records{len(output.stdout)//OUTPUT_BYTES}")
            repeated = subprocess.run([str(work / "placement")], input=payload, capture_output=True, check=True, timeout=30).stdout
        if output.stdout != repeated or len(repeated) != OUTPUT_BYTES * len(ordered):
            raise ValueError("Original city placement did not reproduce exactly")
        results = []
        for index in range(len(cases)):
            raw = repeated[index * OUTPUT_BYTES:(index + 1) * OUTPUT_BYTES]
            opposite = (len(ordered) - 1 - index) * OUTPUT_BYTES
            if raw != repeated[opposite:opposite + OUTPUT_BYTES]:
                raise ValueError("City placement depends on previous calls")
            results.append(decode(raw))
        verify_results(cases, results, resources, variant, sine)
        variants[variant] = {"source_procedure_hashes": hashes, "assembly_sha256": hashlib.sha256(assembly.encode()).hexdigest(),
                             "unreached_adapter_sha256": hashlib.sha256(adapter.encode()).hexdigest(), "host_adapter": adapters,
                             "resources": resources, "results": results}
    report = {"schema": 1, "revision": "original-city-placement-native-v1", "source_sha256": hashlib.sha256(executable).hexdigest(),
              "scope": "Full original F879 two-pass placement, F1533 physical radii and real F574/F575/F576/F579/F582/F581/F1876 terrain chain. Parent/city object IDs and flags follow reviewed F880 setup in a source-sized pool; original object template and model resources are verified against uploaded EXE. No height, radius or model lookup stubs. This is host reference evidence, not a live world integration or whole-EXE equivalence claim. Nonuniform model117 excluded from default cases.",
              "archive_local_sar4_verified_exe_offset": hex(archive_at + 3),
              "case_count": len(cases), "variant_count": 2, "original_terrain_queries_per_placement": 2,
              "fresh_process_reproduction_verified": True, "same_process_reverse_reproduction_verified": True,
              "native_placement_arithmetic_independently_checked_against_scalar_integer_model": True,
              "cases": cases, "variants": variants}
    destination = args.project / "tests/fixtures" / args.fixture_name
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, separators=(",", ":")) + "\n")
    print(f"Original city placement: {len(cases)} contexts, {len(variants)} source variants")


if __name__ == "__main__":
    main()
