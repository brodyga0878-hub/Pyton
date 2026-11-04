#!/usr/bin/env python3
"""Execute original F1750 child-frame construction before the model renderer.

Original F1538/F1750/F1740/F1739 and lighting normalization kernels execute.
F1687 records its arguments and returns no frustum cull; F1773 captures defined
child frame fields and returns without rendering. Parent vertex caches are
explicit valid inputs, and any attempted uncached vertex evaluation traps.
This is composition/metadata evidence, not a full original renderer control.
"""
import argparse
import hashlib
import json
import random
import re
import struct
import subprocess
import tempfile
from pathlib import Path

from extract_ship_registry import Image
from native_reference import procedures

NUMBERS = [1475, 1521, 1538, 1670, 1685, 1739, 1740, 1750]
INPUT_BYTES = 312
OUTPUT_BYTES = 232
ENVIRONMENT = [0x12345678, -123456789, 123456789, -1, 0, 0x23456789]
PERMUTATIONS = [[0, 1, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0], [1, 0, 2], [0, 2, 1]]


def signed(value, bits=32):
    return (value + (1 << (bits - 1))) % (1 << bits) - (1 << (bits - 1))


def blocks(source):
    result = {}
    for number in NUMBERS:
        start = re.search(rf"^FUNC_{number:06d}(?:_[A-Za-z0-9_]+)?:", source, re.M)
        if start is None:
            raise ValueError("Missing original child frame procedure")
        end = re.search(r"^(?:FUNC_\d+(?:_[A-Za-z0-9_]+)?|_[A-Za-z0-9_]+):", source[start.end():], re.M)
        result[number] = source[start.start():start.end() + end.start() if end else len(source)]
    return result


def build_assembly(source, descriptors):
    selected = "\n".join(blocks(source)[n] for n in NUMBERS) + "\nFUNC_999999:\nret\n"
    # Original long negative locals are printed as unsigned hexadecimal. They
    # must be signed before the shared adapter recognizes positive arguments.
    selected = re.sub(r"\[ebp\+0x([89a-f][0-9a-f]{7})\]",
                      lambda m: f"[ebp-0x{-signed(int(m[1], 16)):x}]", selected)
    selected = re.sub(r"add esp,0x([89a-f][0-9a-f]{7})",
                      lambda m: f"add esp,{signed(int(m[1], 16))}", selected)
    selected = re.sub(r"(FUNC_\d+)_[A-Za-z0-9_]+", r"\1", selected)
    lines, _ = procedures(selected, NUMBERS)
    current = None
    for i, line in enumerate(lines):
        if line.startswith("FUNC_"):
            current = line[:-1]
        # Original F1670 discards two 4-byte locals with two POPs, widened to
        # two host 8-byte stack slots; memory offsets and integer math stay.
        if current == "FUNC_001670" and line == "add rsp,-8":
            lines[i] = "add rsp,-16"
    text = "\n".join(lines).replace("SECTION .data", ".section .data").replace("SECTION .text", ".section .text")
    text = re.sub(r"^dd (JUMP_\d+)$", r".long \1", text, flags=re.M)
    text = text.replace("jmp [esi*4+DATA_000049]", "mov r11d,DWORD PTR [esi*4+DATA_000049]\njmp r11")
    result = [".intel_syntax noprefix", ".code64", ".section .text", ".global _start", text]
    result.append("""
.section .text
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 mov esi,OFFSET FLAT:input
 add rsi,r8
 mov edx,312
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,312
 jne read_more
 xor eax,eax
 mov edi,OFFSET FLAT:parent
 mov ecx,256
 rep stosd
 mov edi,OFFSET FLAT:cache
 mov ecx,2304
 rep stosd
 mov edi,OFFSET FLAT:origin_vertex
 mov ecx,9
 rep stosd
 mov edi,OFFSET FLAT:output
 mov ecx,58
 rep stosd
 mov esi,OFFSET FLAT:input+40
 mov edi,OFFSET FLAT:parent+0x14
 mov ecx,9
 rep movsd
 mov esi,OFFSET FLAT:input+76
 mov edi,OFFSET FLAT:parent+0x9c
 mov ecx,9
 rep movsd
 mov esi,OFFSET FLAT:input+112
 mov edi,OFFSET FLAT:origin_vertex+4
 mov ecx,3
 rep movsd
 mov esi,OFFSET FLAT:input+124
 mov edi,OFFSET FLAT:parent+0x134
 mov ecx,3
 rep movsd
 mov esi,OFFSET FLAT:input+28
 mov edi,OFFSET FLAT:parent+0x54
 mov ecx,3
 rep movsd
 mov eax,DWORD PTR [input+12]
 mov DWORD PTR [parent+0x130],eax
 mov eax,DWORD PTR [input+16]
 mov DWORD PTR [parent+0xf8],eax
 mov eax,DWORD PTR [input+20]
 mov DWORD PTR [parent+0xfc],eax
 mov DWORD PTR [parent+0x14c],OFFSET FLAT:entity
 mov DWORD PTR [parent+0xf0],2
 mov DWORD PTR [origin_vertex+0x14],2
 mov eax,DWORD PTR [input+140]
 mov DWORD PTR [operand],eax
 mov esi,OFFSET FLAT:input+144
 mov edi,OFFSET FLAT:cache+122*36
 mov ecx,14
copy_cache_vertex:
 mov eax,DWORD PTR [esi]
 mov DWORD PTR [edi+4],eax
 mov eax,DWORD PTR [esi+4]
 mov DWORD PTR [edi+8],eax
 mov eax,DWORD PTR [esi+8]
 mov DWORD PTR [edi+12],eax
 mov DWORD PTR [edi+0x14],2
 add esi,12
 add edi,36
 dec ecx
 jnz copy_cache_vertex
 mov eax,DWORD PTR [input+4]
 push rax
 mov eax,DWORD PTR [input]
 push rax
 mov eax,DWORD PTR [input+8]
 push rax
 mov eax,DWORD PTR [input+24]
 push rax
 push OFFSET FLAT:origin_vertex
 push OFFSET FLAT:operand
 push OFFSET FLAT:parent
 call FUNC_001750
 add rsp,56
 sub eax,OFFSET FLAT:operand
 mov DWORD PTR [output],eax
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,232
 syscall
 jmp next_case
finished:
 mov eax,60
 xor edi,edi
 syscall
FUNC_001687:
 mov eax,DWORD PTR [rsp+16]
 mov DWORD PTR [output+4],eax
 mov eax,DWORD PTR [rsp+8]
 mov edx,DWORD PTR [eax]
 mov DWORD PTR [output+156],edx
 mov edx,DWORD PTR [eax+4]
 mov DWORD PTR [output+160],edx
 mov edx,DWORD PTR [eax+8]
 mov DWORD PTR [output+164],edx
 xor eax,eax
 ret
FUNC_001773:
 push rbp
 mov rbp,rsp
 push rbx
 push rsi
 push rdi
 mov r10d,DWORD PTR [rbp+16]
 inc DWORD PTR [output+8]
 xor eax,eax
 cmp DWORD PTR [r10+0x14c],OFFSET FLAT:entity
 sete al
 mov DWORD PTR [output+12],eax
 lea esi,[r10+0x14]
 mov edi,OFFSET FLAT:output+16
 mov ecx,9
 rep movsd
 lea esi,[r10+4]
 mov edi,OFFSET FLAT:output+52
 mov ecx,3
 rep movsd
 mov eax,DWORD PTR [r10+0xf8]
 mov DWORD PTR [output+64],eax
 mov eax,DWORD PTR [r10+0x148]
 mov DWORD PTR [output+68],eax
 mov eax,DWORD PTR [r10+0x130]
 mov DWORD PTR [output+72],eax
 lea esi,[r10+0x54]
 mov edi,OFFSET FLAT:output+76
 mov ecx,3
 rep movsd
 mov ax,WORD PTR [r10+0xf4]
 mov WORD PTR [output+88],ax
 mov al,BYTE PTR [r10+0xf6]
 mov BYTE PTR [output+90],al
 mov ecx,DWORD PTR [input+136]
 mov DWORD PTR [output+92],ecx
 lea r11d,[r10+0x70]
 mov edi,OFFSET FLAT:output+96
capture_anchor:
 mov eax,DWORD PTR [r11]
 mov edx,DWORD PTR [eax+4]
 sub edx,DWORD PTR [r10+4]
 mov DWORD PTR [edi],edx
 mov edx,DWORD PTR [eax+8]
 sub edx,DWORD PTR [r10+8]
 mov DWORD PTR [edi+4],edx
 mov edx,DWORD PTR [eax+12]
 sub edx,DWORD PTR [r10+12]
 mov DWORD PTR [edi+8],edx
 add r11d,4
 add edi,12
 dec ecx
 jnz capture_anchor
 lea esi,[r10+0x84]
 mov edi,OFFSET FLAT:output+168
 mov ecx,6
 rep movsd
 test DWORD PTR [input+4],0x4000
 jnz capture_done
 lea esi,[r10+0x134]
 mov edi,OFFSET FLAT:output+192
 mov ecx,3
 rep movsd
 lea esi,[r10+0x38]
 mov edi,OFFSET FLAT:output+204
 mov ecx,3
 rep movsd
 lea esi,[r10+0x44]
 mov edi,OFFSET FLAT:output+216
 mov ecx,4
 rep movsd
capture_done:
 pop rdi
 pop rsi
 pop rbx
 pop rbp
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
unsupported:
 mov eax,60
 mov edi,98
 syscall
.section .data
DATA_007756: .quad FUNC_001538
DATA_007727: .quad unsupported
DATA_009200: .long cache+128*36
DATA_008831:
""")
    result.append(".long " + ",".join(str(v) for v in ENVIRONMENT))
    result.append("DATA_004681:")
    for model in range(max(descriptors) + 1):
        result.append(f".long descriptor_{model}" if model in descriptors else ".long unsupported")
    for model, raw in descriptors.items():
        result.extend([f"descriptor_{model}:", ".byte " + ",".join(str(v) for v in raw)])
    result.append(".section .bss\ninput: .zero 312\noutput: .zero 232\nparent: .zero 1024\nentity: .zero 1024\ncache: .zero 9216\norigin_vertex: .zero 36\noperand: .zero 4\n.balign 16\nstack: .zero 1048576\nstack_end:\n")
    return "\n".join(result) + "\n"


def mul(a, b):
    return signed((signed(a) * signed(b)) >> 31)


def transform_transpose(vector, matrix):
    return [signed(sum(mul(vector[k], matrix[axis * 3 + k]) for k in range(3))) for axis in range(3)]


def oriented(case):
    word = case["placement_word_u16"]
    permutation = (word >> 8) & 7
    if permutation == 6:
        return case["parent_aux_matrix_q31"], case["parent_aux_parity_i32"]
    matrix = [0] * 9
    parity = case["parent_parity_i32"]
    if permutation >= 3:
        parity = signed(~parity)
    for axis in range(3):
        negate = bool(word & (0x2000 >> axis))
        for k in range(3):
            value = case["parent_matrix_q31"][axis * 3 + k]
            matrix[PERMUTATIONS[permutation][axis] * 3 + k] = signed(-value if negate else value)
        if negate:
            parity = signed(~parity)
    return matrix, parity


def verify_cases(cases, descriptors):
    for case in cases:
        result = case["result"]
        descriptor = descriptors[case["child_model_index"]]
        first_scale, second_scale, radius = struct.unpack_from("<3i", descriptor, 0x14)
        scale = signed(case["extra_scale_i32"] + first_scale + second_scale - case["parent_range_scale_i32"])
        matrix, parity = oriented(case)
        origin = case["origin_vertex_i32"]
        relative = [[0, 0, 0]]
        if case["placement_word_u16"] & 0x8000:
            first, second, third, fourth = case["anchor_operand_u8"]
            for index in [third, first, second, fourth]:
                if index == 127:
                    break
                vertex = case["cached_parent_vertices_i32"][signed(index, 8) + 6]
                relative.append([signed(vertex[k] - origin[k]) for k in range(3)])
        expected = {"pc_delta_i32": 4 if case["placement_word_u16"] & 0x8000 else 0,
                    "frustum_radius_i32": signed(radius << (scale & 31)), "renderer_capture_calls": 1,
                    "entity_pointer_inherited": True, "matrix_q31": matrix, "origin_i32": origin,
                    "parity_i32": parity, "scale_i32": scale, "range_scale_i32": case["parent_range_scale_i32"],
                    "locals_0_1_2_i32": [signed(case["parent_locals_0_1_2_i32"][0] + 1), *case["parent_locals_0_1_2_i32"][1:]],
                    "colour_rgb_u8": case["child_colour_rgb_u8"], "external_anchors_relative_i32": relative,
                    "frustum_origin_i32": origin, "environment_i32": ENVIRONMENT}
        if not case["placement_word_u16"] & 0x4000:
            values = [signed(-v) if v < 0 else v for v in origin]
            mask = (values[0] | values[1] | values[2]) & 0xffffffff
            shift = 0
            while mask >= 0x4000:
                mask >>= 1
                shift += 1
            normalized = [v >> shift for v in origin]
            difference = signed(shift + 7 - scale)
            extra_shift = signed(-difference) if difference < 0 else 0
            normalized = [signed(-(v >> (extra_shift & 31))) for v in normalized]
            expected["lighting"] = {"inherited_light_i32": case["parent_light_i32"],
                                    "local_light_i32": transform_transpose(case["parent_light_i32"], matrix),
                                    "view_exponent_i32": signed(shift + extra_shift),
                                    "local_view_i32": transform_transpose(normalized, matrix)}
        else:
            expected["lighting"] = None
        for field, value in expected.items():
            if result[field] != value:
                raise ValueError(f"Native F1750 {case['origin']} model{case['child_model_index']} {field}: {result[field]} != {value}")


def make_cases(models):
    identity = [2147483647, 0, 0, 0, 2147483647, 0, 0, 0, 2147483647]
    quarter = [0, 0, 2147483647, 0, 2147483647, 0, -2147483648, 0, 0]
    dense = [0x43210123, -0x31234567, 0x52345678, -0x61234567, 0x22334455,
             0x12345678, 0x23456789, 0x3456789a, -0x456789ab]
    vertices = [[signed(10101 * i - 8787), signed(-7654 * i + 3456), signed(2345 * i + 6789)] for i in range(14)]
    cases = []

    def add(model, word, extra=0, range_scale=0, matrix=identity, origin=(1234, -5678, 900000),
            anchors=(0, 1, 2, 3), locals_=(0, 3, 0xffff), label="placement"):
        cases.append({"origin": label, "child_model_index": model, "placement_word_u16": word,
                      "extra_scale_i32": extra, "parent_range_scale_i32": range_scale,
                      "parent_parity_i32": 0x12345678, "parent_aux_parity_i32": -0x12345678,
                      "child_colour_rgb_u8": [0x12, 0x34, 0x56], "parent_locals_0_1_2_i32": list(locals_),
                      "parent_matrix_q31": matrix, "parent_aux_matrix_q31": dense, "origin_vertex_i32": list(origin),
                      "parent_light_i32": [0x12345678, -0x23456789, 0x3456789a],
                      "anchor_operand_u8": list(anchors), "cached_parent_vertices_i32": vertices})

    # Every extracted descriptor gets its own original lookup/scale construction.
    for model in models:
        add(model, 0, label="all_original_descriptors")
    for model in [227, 252, 269, 270, 312, 366]:
        if model not in models:
            raise ValueError("Missing city composition reference descriptor")
        for permutation in range(7):
            for signs in range(8):
                word = (permutation << 8) | (signs << 11)
                for matrix in [identity, quarter, dense]:
                    add(model, word, matrix=matrix)
        for word in [0x8000, 0xc000, 0x8600, 0xbe00]:
            for anchors in [(0, 1, 2, 3), (127, 1, 2, 3), (0, 127, 2, 3),
                            (0, 1, 2, 127), (250, 251, 252, 253)]:
                add(model, word, anchors=anchors, matrix=dense, label="external_anchor_order_and_sentinels")
        for extra in [-2147483648, -8, -1, 0, 1, 3, 4, 7, 31, 32, 2147483647]:
            for range_scale in [0, 4, 12, 31, 32]:
                add(model, 0x3d00, extra, range_scale, label="source_extra_and_range_scales")
        for origin in [(0, 0, 0), (-1, 1, -1), (16383, 16384, -16384),
                       (-2147483648, 2147483647, -1), (123456789, -234567890, 345678901)]:
            add(model, 0, origin=origin, label="origin_normalization_bounds")
        for locals_ in [(0, 0, 0), (-1, -1, -1), (2147483647, -2147483648, 0x12345678)]:
            add(model, 0, locals_=locals_, label="inherited_parameter_bounds")
    randomizer = random.Random(17501740)
    for _ in range(120):
        model = randomizer.choice(list(models))
        add(model, (randomizer.randrange(7) << 8) | (randomizer.randrange(8) << 11),
            extra=randomizer.randrange(-32, 33), range_scale=randomizer.randrange(33),
            origin=[randomizer.randrange(-2147483648, 2147483648) for _ in range(3)], label="random_frame")
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("executable", type=Path)
    parser.add_argument("--project", type=Path, default=Path(__file__).parents[1])
    args = parser.parse_args()
    source = args.source.read_text()
    executable = args.executable.read_bytes()
    Image(executable)
    inventory = json.loads((args.project / "data/ffe_world_models.json").read_text())
    if inventory["source_sha256"] != hashlib.sha256(executable).hexdigest():
        raise ValueError("World model descriptor source revision differs")
    descriptors = {}
    for key, model in inventory["models"].items():
        at = model["descriptor_offset"]
        raw = executable[at:at + 68]
        if len(raw) != 68 or hashlib.sha256(raw).hexdigest() != model["descriptor_sha256"]:
            raise ValueError("Model descriptor differs from uploaded executable")
        descriptors[int(key)] = raw
    cases = make_cases(descriptors)
    payloads = []
    for case in cases:
        anchor_count = 1
        if case["placement_word_u16"] & 0x8000:
            a, b, c, d = case["anchor_operand_u8"]
            for index in [c, a, b, d]:
                if index == 127:
                    break
                anchor_count += 1
        rgb = case["child_colour_rgb_u8"]
        header = [case["child_model_index"], case["placement_word_u16"], case["extra_scale_i32"],
                  case["parent_range_scale_i32"], case["parent_parity_i32"], case["parent_aux_parity_i32"],
                  rgb[0] | rgb[1] << 8 | rgb[2] << 16, *case["parent_locals_0_1_2_i32"],
                  *case["parent_matrix_q31"], *case["parent_aux_matrix_q31"], *case["origin_vertex_i32"],
                  *case["parent_light_i32"], anchor_count]
        vertices = [value for row in case["cached_parent_vertices_i32"] for value in row]
        payloads.append(struct.pack("<35I", *(v & 0xffffffff for v in header)) + bytes(case["anchor_operand_u8"]) +
                        struct.pack("<42I", *(v & 0xffffffff for v in vertices)))
    assembly = build_assembly(source, descriptors)
    with tempfile.TemporaryDirectory(prefix="ffe-child-frame-") as directory:
        path = Path(directory)
        (path / "frames.s").write_text(assembly)
        subprocess.run(["as", "--64", str(path / "frames.s"), "-o", str(path / "frames.o")], check=True)
        subprocess.run(["ld", "-m", "elf_x86_64", str(path / "frames.o"), "-o", str(path / "frames")], check=True)
        output = subprocess.run([str(path / "frames")], input=b"".join(payloads), stdout=subprocess.PIPE, check=True, timeout=20).stdout
        repeated = subprocess.run([str(path / "frames")], input=b"".join(payloads), stdout=subprocess.PIPE, check=True, timeout=20).stdout
    if output != repeated or len(output) != OUTPUT_BYTES * len(cases):
        raise ValueError("Original child frame controls did not reproduce")
    for index, case in enumerate(cases):
        raw = output[index * OUTPUT_BYTES:(index + 1) * OUTPUT_BYTES]
        words = struct.unpack("<58i", raw)
        count = words[23]
        case["result"] = {"pc_delta_i32": words[0], "frustum_radius_i32": words[1],
                          "renderer_capture_calls": words[2], "entity_pointer_inherited": bool(words[3]),
                          "matrix_q31": list(words[4:13]), "origin_i32": list(words[13:16]),
                          "parity_i32": words[16], "scale_i32": words[17], "range_scale_i32": words[18],
                          "locals_0_1_2_i32": list(words[19:22]), "colour_rgb_u8": list(raw[88:91]),
                          "external_anchors_relative_i32": [list(words[i:i + 3]) for i in range(24, 24 + count * 3, 3)],
                          "frustum_origin_i32": list(words[39:42]), "environment_i32": list(words[42:48]),
                          "lighting": None if case["placement_word_u16"] & 0x4000 else
                              {"inherited_light_i32": list(words[48:51]), "local_light_i32": list(words[51:54]),
                               "view_exponent_i32": words[54], "local_view_i32": list(words[55:58])}}
    verify_cases(cases, descriptors)
    report = {"schema": 1, "revision": "model-child-frame-native-v1",
              "source_sha256": hashlib.sha256(executable).hexdigest(),
              "source_procedure_hashes": {str(n): hashlib.sha256(body.encode()).hexdigest() for n, body in blocks(source).items()},
              "assembly_sha256": hashlib.sha256(assembly.encode()).hexdigest(),
              "scope": "Actual F1750 child frame, F1538 descriptor lookup, F1740/F1739 orientation and F1685/F1475/F1670/F1521 lighting kernels. F1687 captures cull args and returns no-cull; F1773 captures defined fields only and skips renderer. Parent vertices are supplied valid cached inputs; unexpected F1471 traps. No frustum culling, command27 operand/color decoding, projection, renderer or uninitialized child parameters3..7 claims. Permutation7 and anchor third=127 unsupported. Relative external anchors are observed through actual child pointers, not a substitute vertex evaluator.",
              "fresh_process_reproduction_verified": True, "native_outputs_independently_checked_against_scalar_integer_model": True,
              "descriptor_hashes": {str(model): hashlib.sha256(raw).hexdigest() for model, raw in descriptors.items()},
              "cases": cases}
    (args.project / "tests/fixtures/model_child_frame_reference.json").write_text(json.dumps(report, separators=(",", ":")) + "\n")
    print(f"Original child frame controls: {len(cases)} cases, {len(descriptors)} original descriptors")


if __name__ == "__main__":
    main()
