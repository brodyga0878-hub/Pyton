#!/usr/bin/env python3
"""Extract original ground pads and execute F650 allocation/target controls.

The host control runs the full NPC path of original F650 and original integer
F1669/F1521, optionally preceded by original F1674/F1914. The player UI callbacks
trap: the selected NPC IDs never equal the player ID. A verbatim reviewed F880
pad-count selection snippet runs before each F650 call. No rendered mesh bounds
or inferred model312 markers are used as landing target coordinates.
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

from build_ground_reference import SIN_SIGNATURE
from extract_ship_registry import Image
from native_reference import procedures

NUMBERS = [650, 1521, 1669, 1674, 1914]
MODEL_TABLES = {81: 6178, 82: 6178, 83: 6179, 84: 6179, 85: 6177,
                86: 6175, 87: 6179, 88: 6179, 89: 6176, 90: 6179}
TABLE_COUNTS = {6175: 2, 6176: 2, 6177: 2, 6178: 4, 6179: 6}
INPUT_BYTES = 72
OUTPUT_BYTES = 88
STATUS_SENTINEL = 0x11223344
PAD_SENTINEL = 0x55667788
POINT_SENTINELS = [-1010101, -2020202, -3030303]


def signed(value, bits=32):
    return (value + (1 << (bits - 1))) % (1 << bits) - (1 << (bits - 1))


def original_blocks(source):
    result = {}
    for number in NUMBERS:
        start = re.search(rf"^FUNC_{number:06d}(?:_[A-Za-z0-9_]+)?:", source, re.M)
        if start is None:
            raise ValueError("Missing original pad procedure")
        end = re.search(r"^(?:FUNC_\d+(?:_[A-Za-z0-9_]+)?|_[A-Za-z0-9_]+):", source[start.end():], re.M)
        result[number] = source[start.start():start.end() + end.start() if end else len(source)]
    return result


def count_snippet(source):
    start = source.index("\tJUMP_003669:")
    end = source.index("\n", source.index("\tJUMP_003673:", start))
    snippet = source[start:end] + "\n"
    if "mov word [esi+0xce],0x5" not in snippet or snippet.count("mov word [esi+0xce],0x1") != 3:
        raise ValueError("Unexpected original F880 pad-count initialization")
    # The preceding F880 station initialization has already set CE=3. Only the
    # ground-specific decision body is copied here; full F880 is out of scope.
    initial = "\t\tmov word [esi+0xce],0x3\n"
    if initial.strip() not in source:
        raise ValueError("Missing original F880 initial pad limit")
    return initial + snippet


def extract_tables(source_data, executable):
    Image(executable)
    blocks = {}
    for number, count in TABLE_COUNTS.items():
        match = re.search(rf"^DATA_{number:06d}:", source_data, re.M)
        if match is None:
            raise ValueError("Missing original pad table")
        tail = source_data[match.end():]
        end = re.search(r"^DATA_\d+:", tail, re.M)
        block = tail[:end.start()] if end else tail
        values = []
        for line in block.splitlines():
            line = line.split(";")[0].strip()
            if line.startswith("db "):
                values.extend(int(word.strip(), 0) for word in line[3:].split(","))
            elif line:
                raise ValueError("Unexpected non-byte data in original pad table")
        raw = bytes(values)
        if len(raw) != count * 12:
            raise ValueError("Original pad table has an unexpected length")
        blocks[number] = raw
    joined = b"".join(blocks[n] for n in TABLE_COUNTS)
    at = executable.find(joined)
    if at < 0 or executable.find(joined, at + 1) >= 0:
        raise ValueError("Missing or ambiguous uploaded EXE pad tables")
    tables = {}
    cursor = at
    for number, raw in blocks.items():
        if executable[cursor:cursor + len(raw)] != raw:
            raise ValueError("Uploaded EXE pad table disagrees with source bytes")
        words = struct.unpack("<" + "i" * (len(raw) // 4), raw)
        tables[str(number)] = {"label": f"DATA_{number:06d}", "offset": hex(cursor),
                               "byte_length": len(raw), "sha256": hashlib.sha256(raw).hexdigest(),
                               "vectors_i32": [list(words[i:i + 3]) for i in range(0, len(words), 3)]}
        cursor += len(raw)
    return {"tables_offset": hex(at), "tables_byte_length": len(joined),
            "tables_sha256": hashlib.sha256(joined).hexdigest(), "tables": tables}


def build_assembly(source, tables, sine):
    original = original_blocks(source)
    snippet = count_snippet(source)
    selected = "\n".join(original[n] for n in NUMBERS)
    selected += "\nFUNC_999998:\n" + snippet + "ret\nFUNC_999999:\nret\n"
    selected = re.sub(r"(FUNC_\d+)_[A-Za-z0-9_]+", r"\1", selected)
    lines, _ = procedures(selected, NUMBERS + [999998])
    # F1669 discards its two original 4-byte locals with two POP instructions;
    # the host stack slots are 8 bytes. Local offsets and arithmetic are intact.
    current = None
    for i, line in enumerate(lines):
        if line.startswith("FUNC_"):
            current = line[:-1]
        if current == "FUNC_001669" and line == "add rsp,-8":
            lines[i] = "add rsp,-16"
    result = [".intel_syntax noprefix", ".code64", ".section .text", ".global _start", *lines]
    result.append("""
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 mov esi,OFFSET FLAT:input
 add rsi,r8
 mov edx,72
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,72
 jne read_more
 xor eax,eax
 mov edi,OFFSET FLAT:object
 mov ecx,256
 rep stosd
 mov edi,OFFSET FLAT:record
 mov ecx,16
 rep stosd
 mov edi,OFFSET FLAT:output
 mov ecx,22
 rep stosd
 mov DWORD PTR [output+4],0x11223344
 mov DWORD PTR [output+8],0x55667788
 mov esi,OFFSET FLAT:point_sentinels
 mov edi,OFFSET FLAT:output+12
 mov ecx,6
 rep movsd
 mov eax,DWORD PTR [input]
 mov DWORD PTR [object+0x82],eax
 mov WORD PTR [record+0xc],ax
 mov eax,DWORD PTR [input+68]
 mov DWORD PTR [object+0x14c],eax
 mov esi,OFFSET FLAT:input+60
 mov edi,OFFSET FLAT:object+0xd0
 mov ecx,2
 rep movsd
 mov esi,OFFSET FLAT:object
 mov ebx,OFFSET FLAT:record
 call FUNC_999998
 movsx eax,WORD PTR [object+0xce]
 mov DWORD PTR [output+80],eax
 cmp DWORD PTR [input+8],-2
 je pad_count_ready
 mov eax,DWORD PTR [input+8]
 mov WORD PTR [object+0xce],ax
pad_count_ready:
 movsx eax,WORD PTR [object+0xce]
 mov DWORD PTR [output+84],eax
 cmp DWORD PTR [input+12],1
 je build_ground_matrix
 mov esi,OFFSET FLAT:input+24
 mov edi,OFFSET FLAT:object
 mov ecx,9
 rep movsd
 jmp matrix_ready
build_ground_matrix:
 mov eax,DWORD PTR [input+20]
 push rax
 mov eax,DWORD PTR [input+16]
 push rax
 push OFFSET FLAT:object
 call FUNC_001674
 add rsp,24
matrix_ready:
 mov esi,OFFSET FLAT:object
 mov edi,OFFSET FLAT:output+36
 mov ecx,9
 rep movsd
 push OFFSET FLAT:output+8
 push OFFSET FLAT:output+4
 push OFFSET FLAT:output+12
 mov eax,DWORD PTR [input+4]
 push rax
 push OFFSET FLAT:object
 call FUNC_000650
 add rsp,40
 mov DWORD PTR [output],eax
 mov esi,OFFSET FLAT:object+0xd0
 mov edi,OFFSET FLAT:output+72
 mov ecx,2
 rep movsd
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,88
 syscall
 jmp next_case
finished:
 mov eax,60
 xor edi,edi
 syscall
FUNC_000034:
FUNC_000035:
 mov eax,60
 mov edi,97
 syscall
.section .data
DATA_008857: .long 1
DATA_008879: .long 0
point_sentinels: .quad -1010101,-2020202,-3030303
""")
    for number in TABLE_COUNTS:
        result.append(f"DATA_{number:06d}:")
        result.extend(".long " + ",".join(str(v) for v in row)
                      for row in tables[str(number)]["vectors_i32"])
    result.append("DATA_007975:")
    result.extend(".long " + str(value) for value in sine)
    result.append(".section .bss\ninput: .zero 72\noutput: .zero 88\nobject: .zero 1024\nrecord: .zero 64\n.balign 16\nstack: .zero 1048576\nstack_end:\n")
    return "\n".join(result) + "\n"


def sin_q31(angle, table):
    index = angle & 16383
    quadrant = (angle >> 14) & 3
    if quadrant & 1:
        index = 16383 - index
    return -table[index] if quadrant >= 2 else table[index]


def mul(a, b):
    return signed((signed(a) * signed(b)) >> 31)


def matrix_for_angles(phase, inclination, sine):
    sp, cp = sin_q31(phase, sine), sin_q31(phase + 16384, sine)
    sq, cq = sin_q31(inclination, sine), sin_q31(inclination + 16384, sine)
    return [signed(-mul(cp, sq)), cq, mul(sq, sp), mul(cq, cp), sq,
            signed(-mul(cq, sp)), signed(-sp), 0, signed(-cp)]


def source_target(vector, matrix):
    return [signed(sum(mul(vector[k], matrix[k * 3 + axis]) for k in range(3)) << 10)
            for axis in range(3)]


def verify_cases(cases, tables, sine):
    for case in cases:
        model = case["model_index"]
        vectors = tables[str(MODEL_TABLES[model])]["vectors_i32"]
        result = case["result"]
        if result["initialized_last_pad_index_i32"] != len(vectors) - 1:
            raise ValueError("Original F880 pad count disagrees with original table bounds")
        matrix = case["matrix_q31"]
        if case["matrix_source"] == "original_f1674":
            if matrix != matrix_for_angles(case["ground_phase_u16"], case["ground_inclination_u16"], sine):
                raise ValueError("Original F1674 matrix disagrees with independent integer formula")
        elif matrix != case["explicit_matrix_q31"]:
            raise ValueError("Explicit matrix changed before original F650")
        occupancy = case["occupancy_before_u8"].copy()
        chosen = -1
        allocated = 0
        for index in range(result["actual_last_pad_index_i32"], -1, -1):
            slot = signed(occupancy[index], 8)
            if slot == case["npc_id_i32"]:
                chosen = index
                break
            if slot == 0:
                chosen = index
                occupancy[index] = case["npc_id_i32"] & 255
                allocated = -1
                break
        expected = {"return_i32": 0 if chosen >= 0 else -1,
                    "allocation_status_i32": allocated if chosen >= 0 else STATUS_SENTINEL,
                    "selected_pad_i32": chosen if chosen >= 0 else PAD_SENTINEL,
                    "target_vec64_raw": source_target(vectors[chosen], matrix) if chosen >= 0 else POINT_SENTINELS,
                    "occupancy_after_u8": occupancy}
        for field, value in expected.items():
            if result[field] != value:
                raise ValueError(f"Native F650 {case['origin']} {model}: {field} differs from independent scalar source trace")


def make_cases():
    identity = [2147483647, 0, 0, 0, 2147483647, 0, 0, 0, 2147483647]
    matrices = [identity, [0, 0, 2147483647, 0, 2147483647, 0, -2147483648, 0, 0],
                [0x43210123, -0x31234567, 0x52345678, -0x61234567, 0x22334455, 0x12345678,
                 0x23456789, 0x3456789a, -0x456789ab],
                [-2147483648, 2147483647, -1, 2147483647, -2147483648, 1,
                 -2147483648, -2147483648, 2147483647]]
    contexts = [{"origin": "explicit_q31", "matrix_source": "explicit", "explicit_matrix_q31": m} for m in matrices]
    # Original packed constructor records for named ports are loaded separately
    # in main from the existing F874 controls. These pole/quadrant/seam cases do
    # not introduce a geographic axis conversion.
    for phase, inclination in [(0, 0), (16384, 0), (32768, 0), (49152, 0),
                               (0, 16384), (0, 49152), (65535, 1), (1, 65535),
                               (16383, 16385), (32769, 49151)]:
        contexts.append({"origin": "packed_boundary", "matrix_source": "original_f1674",
                         "ground_phase_u16": phase, "ground_inclination_u16": inclination})
    cases = []
    return contexts, cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("executable", type=Path)
    parser.add_argument("--project", type=Path, default=Path(__file__).parents[1])
    args = parser.parse_args()
    source = args.source.read_text()
    executable = args.executable.read_bytes()
    extracted = extract_tables(args.source.with_name("ffedat.asm").read_text(), executable)
    at = executable.find(SIN_SIGNATURE)
    if at < 0 or executable.find(SIN_SIGNATURE, at + 1) >= 0:
        raise ValueError("Missing or ambiguous original sine table")
    sine_raw = executable[at:at + 65536]
    sine = list(struct.unpack("<16384i", sine_raw))
    contexts, cases = make_cases()
    ground_controls = json.loads((args.project / "tests/fixtures/ground_coordinates_reference.json").read_text())
    if ground_controls["source_sha256"] != hashlib.sha256(executable).hexdigest():
        raise ValueError("Ground constructor contexts use a different original executable")
    named_ports = set()
    for row in ground_controls["cases"]:
        if row.get("name_en") in ["London", "New Moscow", "New York", "Apollonius City"]:
            named_ports.add(row["name_en"])
            contexts.append({"origin": "handcrafted_port", "name_en": row["name_en"],
                             "matrix_source": "original_f1674", "ground_phase_u16": row["ground_phase_u16"],
                             "ground_inclination_u16": row["ground_inclination_u16"]})
    procedural = [row for row in ground_controls["cases"] if row["origin"] == "procedural_coordinate_table"]
    if len(named_ports) != 4 or len(procedural) != 16:
        raise ValueError("Missing named/procedural original ground constructor contexts")
    for row in procedural:
        contexts.append({"origin": "procedural_coordinate_table", "matrix_source": "original_f1674",
                         "ground_phase_u16": row["ground_phase_u16"], "ground_inclination_u16": row["ground_inclination_u16"]})
    for context in contexts:
        for model, table_number in MODEL_TABLES.items():
            count = TABLE_COUNTS[table_number]
            configurations = [("all_free", 7, [0] * count, -2),
                              ("all_occupied", 7, [23] * count, -2),
                              ("no_pads", 7, [0] * count, -1)]
            for selected in range(count):
                slots = [23] * count
                slots[selected] = 0
                configurations.append(("specific_free_pad", 7, slots, -2))
                slots = [23] * count
                slots[selected] = 7
                configurations.append(("existing_pad", 7, slots, -2))
            configurations.extend([
                ("higher_free_than_existing", 7, [7] + [0] * (count - 1), -2),
                ("signed_existing_id", -1, [0] * (count - 1) + [255], -2),
                ("unsigned_id_does_not_match_signed_slot", 255, [23] * (count - 1) + [255], -2),
                ("zero_id_matches_free_without_allocating", 0, [0] * count, -2),
                ("signed_byte_min_existing", -128, [23] * (count - 1) + [128], -2),
            ])
            for origin, identifier, occupancy, last_index in configurations:
                cases.append({**context, "matrix_context_origin": context["origin"], "origin": origin,
                              "model_index": model, "npc_id_i32": identifier,
                              "last_pad_index_override_i32": last_index,
                              "occupancy_before_u8": occupancy + [0] * (8 - count)})
    # Full-width signed Q31 coefficients exercise negative-product rounding;
    # deterministic varied occupancies add allocation control coverage.
    randomizer = random.Random(6501669)
    for _ in range(120):
        model = randomizer.choice(list(MODEL_TABLES))
        count = TABLE_COUNTS[MODEL_TABLES[model]]
        cases.append({"origin": "random_integer_state", "matrix_source": "explicit", "model_index": model,
                      "explicit_matrix_q31": [randomizer.randrange(-2147483648, 2147483648) for _ in range(9)],
                      "npc_id_i32": randomizer.choice([7, 127, -1, -128, 255, 0]),
                      "last_pad_index_override_i32": -2,
                      "occupancy_before_u8": [randomizer.choice([0, 7, 23, 127, 128, 255]) for _ in range(count)] + [0] * (8 - count)})
    payloads = []
    for case in cases:
        mode = int(case["matrix_source"] == "original_f1674")
        matrix = case.get("explicit_matrix_q31", [0] * 9)
        words = [case["model_index"], case["npc_id_i32"], case["last_pad_index_override_i32"], mode,
                 case.get("ground_phase_u16", 0), case.get("ground_inclination_u16", 0), *matrix]
        payloads.append(struct.pack("<15I", *(value & 0xffffffff for value in words)) +
                        bytes(case["occupancy_before_u8"]) + struct.pack("<I", 0x40))
    assembly = build_assembly(source, extracted["tables"], sine)
    with tempfile.TemporaryDirectory(prefix="ffe-ground-pads-") as directory:
        path = Path(directory)
        (path / "pads.s").write_text(assembly)
        subprocess.run(["as", "--64", str(path / "pads.s"), "-o", str(path / "pads.o")], check=True)
        subprocess.run(["ld", "-m", "elf_x86_64", str(path / "pads.o"), "-o", str(path / "pads")], check=True)
        output = subprocess.run([str(path / "pads")], input=b"".join(payloads), stdout=subprocess.PIPE, check=True, timeout=20).stdout
        repeated = subprocess.run([str(path / "pads")], input=b"".join(payloads), stdout=subprocess.PIPE, check=True, timeout=20).stdout
    if output != repeated or len(output) != OUTPUT_BYTES * len(cases):
        raise ValueError("Original pad control did not reproduce exactly")
    for i, case in enumerate(cases):
        row = output[i * OUTPUT_BYTES:(i + 1) * OUTPUT_BYTES]
        code, status, selected = struct.unpack_from("<3i", row)
        case["matrix_q31"] = list(struct.unpack_from("<9i", row, 36))
        initial, actual = struct.unpack_from("<2i", row, 80)
        case["result"] = {"return_i32": code, "allocation_status_i32": status, "selected_pad_i32": selected,
                          "target_vec64_raw": list(struct.unpack_from("<3q", row, 12)),
                          "occupancy_after_u8": list(row[72:80]),
                          "initialized_last_pad_index_i32": initial, "actual_last_pad_index_i32": actual}
    verify_cases(cases, extracted["tables"], sine)
    metadata = {"schema": 1, "source_sha256": hashlib.sha256(executable).hexdigest(),
                "source_procedure_hashes": {str(n): hashlib.sha256(body.encode()).hexdigest()
                                            for n, body in original_blocks(source).items()},
                "f880_count_snippet_sha256": hashlib.sha256(count_snippet(source).encode()).hexdigest()}
    data = {**metadata, **extracted,
            "scope": "Original F650 open-air ground pad vectors. Table triples are signed int32 before F1669 matrix transformation and 32-bit SHL10/sign extension to Vec64. F880 pad counts match all model81..90 mappings. No terrain height, player UI, landing permission or rendered model312 inference.",
            "coordinate_shift_after_matrix": 10,
            "models": {str(model): {"table": str(table), "pad_count": TABLE_COUNTS[table],
                                     "last_pad_index": TABLE_COUNTS[table] - 1} for model, table in MODEL_TABLES.items()}}
    report = {**metadata, "revision": "ground-pads-native-v1",
              "scope": "Full original F650 NPC open-air allocation and physical targets, original F1669/F1521 and F1674/F1914 for packed matrix contexts. F880 ground pad count selection runs from a verbatim source snippet after its reviewed CE=3 initialization; this is not full F880. Player ID is1; callbacks F34/F35 abort97 and are never invoked. Original allocation scans descending once, stopping at first free OR same signed-byte occupant. Failure output sentinels are preserved.",
              "tables_sha256": extracted["tables_sha256"], "sine_table_sha256": hashlib.sha256(sine_raw).hexdigest(),
              "assembly_sha256": hashlib.sha256(assembly.encode()).hexdigest(),
              "fresh_process_reproduction_verified": True,
              "native_outputs_independently_checked_against_scalar_integer_model": True,
              "failure_sentinels": {"allocation_status_i32": STATUS_SENTINEL, "selected_pad_i32": PAD_SENTINEL,
                                     "target_vec64_raw": POINT_SENTINELS}, "cases": cases}
    (args.project / "data/ffe_ground_pads.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    (args.project / "tests/fixtures/ground_pads_reference.json").write_text(json.dumps(report, separators=(",", ":")) + "\n")
    print(f"Original ground pads: {len(extracted['tables'])} tables, {len(cases)} native allocation/target controls")


if __name__ == "__main__":
    main()
