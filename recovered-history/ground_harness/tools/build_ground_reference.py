#!/usr/bin/env python3
"""Build host-native F874/F1674 ground-port controls and extract original Q31 sine data.

This assembles reviewed original integer procedures for a host x86_64 control.
The resulting helper is temporary, never Android code and never a DOS emulator.
The controls cover angular packing and the pre-terrain radial matrix; they do not
claim to reproduce F879's original terrain elevation or planetary rotation.
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

from extract_settlement_rules import extract as settlements
from extract_ship_registry import Image
from extract_worlds import extract as worlds
from native_reference import procedures

SIN_SIGNATURE = bytes.fromhex("000000003f2403007e480600be6c0900fd900c003db50f007cd91200bbfd1500")
PROCEDURES = [872, 874, 1521, 1674, 1914]


def original_blocks(source):
    """Select function bodies, also stopping at C-style external labels."""
    result = {}
    for number in PROCEDURES:
        start = re.search(rf"^FUNC_{number:06d}(?:_[A-Za-z0-9_]+)?:", source, re.M)
        if start is None:
            raise ValueError(f"Missing original procedure {number}")
        end = re.search(r"^(?:FUNC_\d+(?:_[A-Za-z0-9_]+)?|_[A-Za-z0-9_]+):", source[start.end():], re.M)
        block = source[start.start(): start.end() + end.start() if end else len(source)]
        result[number] = block
    return result


def assembly(source, table):
    # The shared adapter expects plain numeric labels; this renaming only changes
    # symbols, while the hashes above retain the exact original procedure text.
    selected = "\n".join(original_blocks(source)[n] for n in PROCEDURES) + "\nFUNC_999999:\nret\n"
    normalized = re.sub(r"(FUNC_\d+)_[A-Za-z0-9_]+", r"\1", selected)
    lines, _ = procedures(normalized, PROCEDURES)
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
 mov edx,16
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,16
 jne read_more
 mov edi,OFFSET FLAT:output
 xor eax,eax
 mov ecx,26
 rep stosd
 mov DWORD PTR [DATA_007126],0x1234
 mov DWORD PTR [DATA_007127],0x5678
 cmp DWORD PTR [input],1
 je packed_case
 push OFFSET FLAT:port_name
 push 0x51
 push 2
 mov eax,DWORD PTR [input+8]
 push rax
 mov eax,DWORD PTR [input+4]
 push rax
 mov eax,DWORD PTR [input+12]
 push rax
 push OFFSET FLAT:output
 call FUNC_000874
 add rsp,56
 jmp build_matrix
packed_case:
 mov eax,DWORD PTR [input+4]
 mov WORD PTR [output+18],ax
 mov eax,DWORD PTR [input+8]
 mov WORD PTR [output+34],ax
build_matrix:
 movzx eax,WORD PTR [output+34]
 push rax
 movzx eax,WORD PTR [output+18]
 push rax
 push OFFSET FLAT:output+68
 call FUNC_001674
 add rsp,24
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,104
 syscall
 jmp next_case
finished:
 mov eax,60
 xor edi,edi
 syscall
.section .data
DATA_007126: .long 0
DATA_007127: .long 0
port_name: .asciz "Reference Port"
DATA_007975:
""")
    result.extend(".long " + str(value) for value in table)
    result.append(".section .bss\ninput: .zero 16\noutput: .zero 104\n.balign 16\nstack: .zero 1048576\nstack_end:\n")
    return "\n".join(result) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("executable", type=Path)
    parser.add_argument("--project", type=Path, default=Path(__file__).parents[1])
    args = parser.parse_args()
    source = args.source.read_text()
    executable = args.executable.read_bytes()
    Image(executable)
    at = executable.find(SIN_SIGNATURE)
    if at < 0 or executable.find(SIN_SIGNATURE, at + 1) >= 0:
        raise ValueError("Missing or ambiguous original Q31 sine table")
    raw_table = executable[at:at + 16384 * 4]
    if len(raw_table) != 16384 * 4:
        raise ValueError("Truncated original sine table")
    table = list(struct.unpack("<16384i", raw_table))
    if table[0] != 0 or table[-1] != 0x7ffffff5 or not all(a < b for a, b in zip(table, table[1:])):
        raise ValueError("Unexpected quarter-sine table")
    # Independent checked source resource bytes must agree when available.
    bitmap_source = args.source.with_name("ffebmp.asm")
    bitmap_verified = False
    if bitmap_source.is_file():
        text = bitmap_source.read_text()
        start = text.index("DATA_007975:")
        tail = text[start:]
        end = re.search(r"^DATA_\d+:", tail[1:], re.M)
        block = tail[:1 + end.start()] if end else tail
        resource_bytes = []
        for line in block.splitlines():
            line = line.split(";")[0].strip()
            if line.startswith("db "):
                resource_bytes.extend(int(value.strip(), 0) for value in line[3:].split(","))
        if bytes(resource_bytes) != raw_table:
            raise ValueError("Uploaded EXE sine table differs from reviewed source resource")
        bitmap_verified = True
    hashes = {str(n): hashlib.sha256(block.encode()).hexdigest() for n, block in original_blocks(source).items()}
    source_data = worlds(args.executable)
    cases = []
    payloads = []

    def add_constructor(a, b, origin, name="", seed=0x12345678, system_id=None):
        item = {"origin": origin, "arguments": [a, b], "seed": seed}
        if name:
            item["name_en"] = name
        if system_id is not None:
            item["system_id"] = system_id
        cases.append(item)
        payloads.append(struct.pack("<4I", 0, a & 0xffffffff, b & 0xffffffff, seed))

    def add_packed(p, q, origin):
        cases.append({"origin": origin, "packed_input": [p, q]})
        payloads.append(struct.pack("<4I", 1, p, q, 0))

    for system in source_data["systems"]:
        for row in system["objects"]:
            if int(row["type_code"]) == 35:
                add_constructor(row["latitude_raw"], row["longitude_raw"], "handcrafted", row["name_en"], system_id=system["system_id"])
    for row in source_data["unmatched_fallback"]:
        if int(row["type_code"]) == 35:
            add_constructor(row["latitude_raw"], row["longitude_raw"], "handcrafted_fallback", row["name_en"])
    packed_coordinates = settlements(args.executable)["tables"]["ground_coordinates"]
    for i in range(0, len(packed_coordinates), 2):
        add_packed(packed_coordinates[i + 1], packed_coordinates[i], "procedural_coordinate_table")
    edges = [0, 1, -1, 9000, -9000, 18000, -18000, 27000, -27000, 35999, -35999, 36000, -36000, 65535, -65536, 2147483647, -2147483648]
    for a in edges:
        for b in [0, 9000, -9000, 32767, -32768]:
            add_constructor(a, b, "constructor_boundary", seed=0 if a == 0 else 0x12345678)
    packed_edges = [0, 1, 16383, 16384, 16385, 32767, 32768, 32769, 49151, 49152, 49153, 65534, 65535]
    for p in packed_edges:
        for q in packed_edges:
            add_packed(p, q, "packed_boundary")
    randomizer = random.Random(8741674)
    for _ in range(192):
        add_constructor(randomizer.randrange(-2147483648, 2147483648), randomizer.randrange(-2147483648, 2147483648), "constructor_random")
        add_packed(randomizer.randrange(65536), randomizer.randrange(65536), "packed_random")
    text = assembly(source, table)
    with tempfile.TemporaryDirectory(prefix="ffe-ground-reference-") as directory:
        path = Path(directory)
        (path / "ground.s").write_text(text)
        subprocess.run(["as", "--64", str(path / "ground.s"), "-o", str(path / "ground.o")], check=True)
        subprocess.run(["ld", "-m", "elf_x86_64", str(path / "ground.o"), "-o", str(path / "ground")], check=True)
        output = subprocess.run([str(path / "ground")], input=b"".join(payloads), stdout=subprocess.PIPE, check=True, timeout=20).stdout
    if len(output) != len(cases) * 104:
        raise ValueError("Native controls returned an incomplete result")
    for i, case in enumerate(cases):
        row = output[i * 104:(i + 1) * 104]
        case["ground_phase_u16"] = struct.unpack_from("<H", row, 18)[0]
        case["ground_inclination_u16"] = struct.unpack_from("<H", row, 34)[0]
        case["matrix_q31"] = list(struct.unpack_from("<9i", row, 68))
        case["radial_q31"] = case["matrix_q31"][3:6]
    metadata = {"schema": 1, "source_sha256": hashlib.sha256(executable).hexdigest(), "source_procedure_hashes": hashes, "sine_table_offset": hex(at), "sine_table_sha256": hashlib.sha256(raw_table).hexdigest(), "sine_table_matches_reviewed_resource": bitmap_verified}
    extracted = {**metadata, "scope": "Original DATA_007975 Q31 quarter-sine table. F1914 mirrors indices as 16383-index, retains signed quadrants. F1521 returns signed low32(product >> 31).", "sin_quarter_q31": table}
    report = {**metadata, "scope": "Original unmodified F874 constructor packing, F1674 pre-terrain radial matrix with original F1914 sine and F1521 multiplication. Native x86_64 stack-width adaptation only; no math/vector stubs. Does not validate original F879 terrain/radius corrections or planetary spin.", "assembly_sha256": hashlib.sha256(text.encode()).hexdigest(), "random_seed": 8741674, "cases": cases}
    (args.project / "data/ffe_ground_coordinates.json").write_text(json.dumps(extracted, separators=(",", ":")) + "\n")
    (args.project / "tests/fixtures/ground_coordinates_reference.json").write_text(json.dumps(report, separators=(",", ":")) + "\n")
    print("Original ground controls:", len(cases), "; sine entries:", len(table), "; source resource match:", bitmap_verified)


if __name__ == "__main__":
    main()
