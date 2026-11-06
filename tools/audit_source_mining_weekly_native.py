#!/usr/bin/env python3
"""Run the actual reviewed F243 weekly MB4 branch as a host-only ELF.

This narrow control is not an Android implementation. The only ABI adaptation
is the existing reviewed 64-bit host adapter. Dead recreation callbacks trap.
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
GUARD = 0x4D42345745454B31


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def make_assembly(source: str) -> tuple[str, str]:
    start = re.search(r"^FUNC_000243:", source, re.M)
    end = re.search(r"^FUNC_000244:", source, re.M)
    block = source[start.start():end.start()]
    path = PROJECT / "recovered-history/ground_harness/tools/native_reference.py"
    spec = importlib.util.spec_from_file_location("mining_weekly_host_abi", path)
    adapter = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(adapter)
    lines, _ = adapter.procedures(block + "\nFUNC_999999:\nret\n", [243])
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
 mov edx,2
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,2
 jne read_more
 mov edi,OFFSET FLAT:record
 mov ecx,52
 xor eax,eax
 rep stosb
 mov rax,{GUARD}
 mov QWORD PTR [before],rax
 mov QWORD PTR [after],rax
 mov al,BYTE PTR [input]
 mov BYTE PTR [record+4],al
 mov al,BYTE PTR [input+1]
 mov BYTE PTR [record+5],al
 push OFFSET FLAT:event
 call FUNC_000243
 add rsp,8
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:before
 mov edx,68
 syscall
 jmp next_case
finished:
 xor edi,edi
 mov eax,60
 syscall
FUNC_000244:
trap:
 mov edi,95
 mov eax,60
 syscall
.section .data
event: .long 16
DATA_009104: .long 1
DATA_007219: .quad trap
DATA_006140: .quad trap
DATA_009133: .long 0
DATA_008885: .long 0
DATA_007758: .long 0
DATA_008861: .long 0
.section .bss
input: .zero 2
.balign 8
before: .zero 8
record: .zero 52
after: .zero 8
.set DATA_009108,record+5
.set DATA_009109,record+30
.set DATA_009106,record
stack: .zero 65536
stack_end:
.section .note.GNU-stack,"",@progbits
"""
    return assembly, sha(block.encode())


def main() -> None:
    source_path = Path("/workspace/ffe-upstream/jjffe/ffe.asm")
    raw = source_path.read_bytes()
    if sha(raw) != ASM_SHA:
        raise ValueError("Unexpected reviewed JJFFE assembly")
    source = source_path.read_text()
    assembly, block_sha = make_assembly(source)
    cases = [(hopper, reserve) for hopper in range(11) for reserve in range(256)]
    payload = b"".join(bytes(case) for case in cases)
    with tempfile.TemporaryDirectory(prefix="source-mb4-weekly-") as directory:
        work = Path(directory)
        (work / "native.s").write_text(assembly)
        subprocess.run(["as", "--64", "-o", str(work / "native.o"), str(work / "native.s")], check=True)
        subprocess.run(["ld", "-o", str(work / "native"), str(work / "native.o")], check=True)
        results = [subprocess.run([str(work / "native")], input=payload, capture_output=True, check=True).stdout for _ in range(3)]
        reversed_output = subprocess.run([str(work / "native")], input=b"".join(bytes(case) for case in reversed(cases)), capture_output=True, check=True).stdout
    if len(set(results)) != 1 or len(results[0]) != len(cases) * 68:
        raise ValueError("Unstable or incomplete original F243 output")
    packets = [results[0][i * 68:(i + 1) * 68] for i in range(len(cases))]
    if reversed_output != b"".join(reversed(packets)):
        raise ValueError("Native F243 state depends on case order")
    outputs = []
    for (hopper, reserve), packet in zip(cases, packets):
        if struct.unpack_from("<Q", packet)[0] != GUARD or struct.unpack_from("<Q", packet, 60)[0] != GUARD:
            raise ValueError("Native F243 record guard damaged")
        body = packet[8:60]
        if any(value for index, value in enumerate(body) if index not in [4, 5]):
            raise ValueError("Unexpected native F243 record mutation")
        outputs.append({"hopper_before": hopper, "remaining_raw_before": reserve, "hopper_after": body[4], "remaining_raw_after": body[5]})
    report = {
        "schema": 1,
        "scope": "Actual F243 event0x10 weekly branch only; one52-byte MB4 record, valid hopper0..10 and all256 reserve bytes. Dead recreation callbacks trap. Host ABI adaptation only, not Android implementation, full deployment, weekly scheduler execution or original EXE binary execution.",
        "source_commit": "7e540341d4e09aa3c92877b87d49e7f2c143ad8d",
        "source_assembly_sha256": ASM_SHA,
        "f243_sha256": block_sha,
        "adapted_assembly_sha256": sha(assembly.encode()),
        "input_packets_sha256": sha(payload),
        "native_output_sha256": sha(results[0]),
        "case_count": len(cases),
        "fresh_process_runs": 3,
        "reverse_order_repeat_cases": len(cases),
        "record_guards_unchanged": True,
        "non_hopper_reserve_record_bytes_unchanged": True,
        "water_ff_behavior": [row for row in outputs if row["remaining_raw_before"] == 255],
        "boundary_examples": [row for row in outputs if row["hopper_before"] in [0, 9, 10] and row["remaining_raw_before"] in [0, 1, 127, 128, 255]],
        "cases": outputs,
    }
    output = PROJECT / "tests/fixtures/source_mining_weekly_native.json"
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"case_count": len(cases), "fresh_process_runs": 3, "guards_ok": True, "water_ff_hopper0": report["water_ff_behavior"][0], "fixture_sha256": sha(output.read_bytes())}))


if __name__ == "__main__":
    main()
