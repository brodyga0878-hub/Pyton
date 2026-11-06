#!/usr/bin/env python3
"""Execute original F247/F252 normal-MB4 hopper loading as a host-only ELF.

Object lookup, message/UI notification are explicit narrow host adapters. The
normal model110 path runs actual source instructions, including commodity
selection, hopper mutation and the request for a later retrieval animation.
No F246 deployment/F253 retrieval animation is executed by this control.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import re
import struct
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[1]
ASM_SHA = "d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a"
DAT_SHA = "34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850"
EXE_SHA = "d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
GUARD = 0x4D42344C4F414431


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def procedure(source: str, number: int) -> str:
    start = re.search(rf"^FUNC_{number:06d}:", source, re.M)
    end = re.search(r"^FUNC_\d+(?:_[A-Za-z0-9_]+)?:", source[start.end():], re.M)
    return source[start.start():start.end() + end.start()]


def numeric_bytes(source: str, label: str, size: int) -> bytes:
    tail = source[source.index(label + ":") + len(label) + 1:]
    result = bytearray()
    for line in tail.splitlines():
        line = line.split(";")[0].strip()
        if not line.startswith("db "):
            if line.startswith(("dd ", "dw ")):
                raise ValueError("Unexpected source pointer/word before complete bytes")
            continue
        for token in line[3:].split(","):
            result.append(int(token.strip(), 0))
            if len(result) == size:
                return bytes(result)
    raise ValueError("Incomplete source bytes")


def make_assembly(source: str, commodity_map: bytes) -> tuple[str, dict]:
    blocks = [procedure(source, number) for number in [247, 252]]
    path = PROJECT / "recovered-history/ground_harness/tools/native_reference.py"
    spec = importlib.util.spec_from_file_location("mining_load_host_abi", path)
    adapter = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(adapter)
    lines, _ = adapter.procedures("\n".join(blocks) + "\nFUNC_999999:\nret\n", [247, 252])
    assembly = ".intel_syntax noprefix\n.code64\n.section .text\n.global _start\n"
    assembly += "\n".join(lines)
    assembly += f"""
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 mov esi,OFFSET FLAT:input
 add rsi,r8
 mov edx,6
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,6
 jne read_more
 mov edi,OFFSET FLAT:record
 mov ecx,52
 xor eax,eax
 rep stosb
 mov edi,OFFSET FLAT:body
 mov ecx,338
 rep stosb
 mov edi,OFFSET FLAT:DATA_008896
 mov ecx,64
 rep stosb
 mov DWORD PTR [DATA_008891],0
 mov DWORD PTR [last_message],0
 mov WORD PTR [DATA_008860],16
 mov DWORD PTR [body+0x82],110
 mov BYTE PTR [body+0x86],17
 mov BYTE PTR [record+30],17
 mov al,BYTE PTR [input]
 mov BYTE PTR [record+4],al
 mov al,BYTE PTR [input+1]
 mov BYTE PTR [record+31],al
 mov eax,DWORD PTR [input+2]
 mov DWORD PTR [DATA_008889],eax
 mov rax,{GUARD}
 mov QWORD PTR [before],rax
 mov QWORD PTR [after],rax
 call FUNC_000247
 mov esi,OFFSET FLAT:record
 mov edi,OFFSET FLAT:output
 mov ecx,52
 rep movsb
 mov eax,DWORD PTR [DATA_008891]
 mov DWORD PTR [output+52],eax
 mov esi,OFFSET FLAT:DATA_008896
 mov edi,OFFSET FLAT:output+56
 mov ecx,64
 rep movsb
 mov ax,WORD PTR [DATA_008860]
 mov WORD PTR [output+120],ax
 mov al,BYTE PTR [body+0xff]
 mov BYTE PTR [output+122],al
 mov eax,DWORD PTR [last_message]
 mov DWORD PTR [output+123],eax
 mov rax,QWORD PTR [before]
 mov QWORD PTR [output+127],rax
 mov rax,QWORD PTR [after]
 mov QWORD PTR [output+135],rax
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:output
 mov edx,143
 syscall
 jmp next_case
finished:
 xor edi,edi
 mov eax,60
 syscall
lookup_body:
 mov eax,OFFSET FLAT:body
 ret
FUNC_000349:
 mov rax,QWORD PTR [rsp+8]
 mov eax,DWORD PTR [rax]
 mov DWORD PTR [last_message],eax
 ret
FUNC_000148:
 ret
.section .data
DATA_009104: .long 1
DATA_009133: .long 0
DATA_009113: .byte 17
DATA_007754: .quad lookup_body
DATA_005058: .byte {','.join(str(value) for value in commodity_map)}
.section .bss
input: .zero 6
body: .zero 338
output: .zero 143
DATA_008889: .zero 4
DATA_008891: .zero 4
DATA_008860: .zero 2
DATA_008905: .zero 2
DATA_008896: .zero 64
last_message: .zero 4
.balign 8
before: .zero 8
record: .zero 52
after: .zero 8
.set DATA_009106,record
.set DATA_009107,record+4
.set DATA_009109,record+30
.set DATA_009110,record+31
stack: .zero 65536
stack_end:
.section .note.GNU-stack,"",@progbits
"""
    return assembly, {str(number): sha(block.encode()) for number, block in zip([247, 252], blocks)}


def main() -> None:
    source_path = Path("/workspace/ffe-upstream/jjffe/ffe.asm")
    data_path = source_path.with_name("ffedat.asm")
    exe = Path("/workspace/ffe-original/FIRSTENC.EXE").read_bytes()
    if sha(source_path.read_bytes()) != ASM_SHA or sha(data_path.read_bytes()) != DAT_SHA or sha(exe) != EXE_SHA:
        raise ValueError("Unexpected reviewed original input")
    source, data = source_path.read_text(), data_path.read_text()
    commodity_map = numeric_bytes(data, "DATA_005058", 9)
    at = exe.find(commodity_map)
    if at < 0 or exe.find(commodity_map, at + 1) >= 0:
        raise ValueError("Commodity map not uniquely verified in original EXE")
    assembly, block_hashes = make_assembly(source, commodity_map)
    cases = [(hopper, prospect, free) for hopper in range(11) for prospect in range(9) for free in [0, 1, 2, 5, 9, 10, 29, 30, 31, 100]]
    payload = b"".join(struct.pack("<BBI", *case) for case in cases)
    with tempfile.TemporaryDirectory(prefix="source-mb4-load-") as directory:
        work = Path(directory)
        (work / "native.s").write_text(assembly)
        subprocess.run(["as", "--64", "-o", str(work / "native.o"), str(work / "native.s")], check=True)
        subprocess.run(["ld", "-o", str(work / "native"), str(work / "native.o")], check=True)
        results = [subprocess.run([str(work / "native")], input=payload, capture_output=True, check=True).stdout for _ in range(3)]
        reverse = subprocess.run([str(work / "native")], input=b"".join(struct.pack("<BBI", *case) for case in reversed(cases)), capture_output=True, check=True).stdout
    if len(set(results)) != 1 or len(results[0]) != len(cases) * 143:
        raise ValueError("Unstable or incomplete original F247 output")
    packets = [results[0][i * 143:(i + 1) * 143] for i in range(len(cases))]
    if reverse != b"".join(reversed(packets)):
        raise ValueError("Native F247 case order leaked state")
    outputs = []
    for (hopper, prospect, free), packet in zip(cases, packets):
        if struct.unpack_from("<Q", packet, 127)[0] != GUARD or struct.unpack_from("<Q", packet, 135)[0] != GUARD:
            raise ValueError("Native F247 record guard damaged")
        original = bytearray(52)
        original[4], original[30], original[31] = hopper, 17, prospect
        if any(packet[k] != original[k] for k in range(52) if k != 4):
            raise ValueError("Unexpected original F247 record mutation")
        outputs.append({"hopper_before": hopper, "prospect": prospect, "free_cargo_tonnes": free, "hopper_after": packet[4], "cargo_used_added": struct.unpack_from("<I", packet, 52)[0], "commodity_tonnes_added": list(struct.unpack_from("<32H", packet, 56)), "near_machine_flag_after": struct.unpack_from("<H", packet, 120)[0], "retrieval_animation_requested": packet[122] == 255, "message_ffcode": struct.unpack_from("<I", packet, 123)[0]})
    report = {
        "schema": 1,
        "scope": "Actual normal model110 F247 and actual F252 lookup; tested hopper0..10, prospect0..8, nonnegative free cargo including29/30tonnes. Lookup returns a prepared original-size body, message/UI callbacks are explicit host adapters. Record/cargo mutation and retrieval request are original instructions. Does not execute deployment F246, retrieval F253, docking or Android gameplay.",
        "source_commit": "7e540341d4e09aa3c92877b87d49e7f2c143ad8d",
        "source_executable_sha256": EXE_SHA,
        "source_assembly_sha256": ASM_SHA,
        "source_data_sha256": DAT_SHA,
        "source_function_sha256": block_hashes,
        "commodity_map": list(commodity_map),
        "commodity_map_executable_offset": at,
        "commodity_map_original_executable_verified": True,
        "adapted_assembly_sha256": sha(assembly.encode()),
        "input_packets_sha256": sha(payload),
        "native_output_sha256": sha(results[0]),
        "case_count": len(cases),
        "fresh_process_runs": 3,
        "reverse_order_repeat_cases": len(cases),
        "record_guards_unchanged": True,
        "non_hopper_record_bytes_unchanged": True,
        "cases": outputs,
    }
    output = PROJECT / "tests/fixtures/source_mining_load_native.json"
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"case_count": len(cases), "fresh_process_runs": 3, "guards_ok": True, "commodity_map_executable_offset": at, "fixture_sha256": sha(output.read_bytes())}))


if __name__ == "__main__":
    main()
