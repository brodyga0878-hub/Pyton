#!/usr/bin/env python3
"""Independent reviewed JJFFE time-control instructions in a host-only ELF.

F207/F208/F217/F220 execute with GUI callbacks reduced to argument recorders.
F1418 executes with timestamp supplied by the case and its unrelated 50 Hz
callback held just ahead of that timestamp. This proves acceleration selection,
pause/play state and timer arithmetic, not the original full physics scheduler.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import random
import re
import struct
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[1]
ASM_SHA = "d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a"
GUARD = 0x54494D45434C4B31
TIMERS = [994, 9942, 99420, 994200, 9942000]
STATE_NAMES = ["temporary_timer", "temporary_shift", "timer", "shift", "clock_low", "frame_step", "accelerated_counter", "system_counter", "last_action", "button_image", "button_index", "last_timestamp"]


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def procedure(source: str, number: int) -> str:
    match = re.search(rf"^FUNC_{number:06d}(?:_[A-Za-z0-9_]+)?:", source, re.M)
    if match is None:
        raise ValueError(f"Missing source procedure {number}")
    following = re.search(r"^FUNC_\d+(?:_[A-Za-z0-9_]+)?:", source[match.end():], re.M)
    if following is None:
        raise ValueError("Missing end marker")
    return source[match.start():match.end() + following.start()]


def make_assembly(source: str) -> tuple[str, dict]:
    numbers = [207, 208, 217, 220, 1418]
    blocks = [procedure(source, number) for number in numbers]
    joined = "\n".join(blocks) + "\nFUNC_999999:\nret\n"
    joined = re.sub(r"(FUNC_\d+)_[A-Za-z0-9_]+", r"\1", joined)
    adapter_path = PROJECT / "recovered-history/ground_harness/tools/native_reference.py"
    spec = importlib.util.spec_from_file_location("source_time_host_abi", adapter_path)
    adapter = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(adapter)
    lines, _ = adapter.procedures(joined, numbers)
    adapted = []
    for line in lines:
        if line == "SECTION .data":
            adapted.append(".section .data")
        elif line == "SECTION .text":
            adapted.append(".section .text")
        elif line.startswith("dd "):
            adapted.append(".quad " + line[3:])
        elif line == "jmp [eax*4+DATA_000016]":
            adapted.append("jmp QWORD PTR [rax*8+DATA_000016]")
        elif re.fullmatch(r"\.[A-Za-z0-9_]+", line):
            # NASM accepts a label without ':', GAS requires the punctuation.
            adapted.append(line + ":")
        else:
            adapted.append(line)
    if "jmp QWORD PTR [rax*8+DATA_000016]" not in adapted:
        raise ValueError("Unreviewed source jump-table layout")
    assembly = ".intel_syntax noprefix\n.code64\n.section .text\n.global _start\n" + "\n".join(adapted)
    assembly += f"""
gui_get:
 mov eax,DWORD PTR [input+4]
 ret
gui_set:
 mov r11d,DWORD PTR [rsp+8]
 mov DWORD PTR [state+32],r11d
 ret
FUNC_000262:
 mov r11d,DWORD PTR [rsp+8]
 mov DWORD PTR [state+36],r11d
 mov r11d,DWORD PTR [rsp+16]
 mov DWORD PTR [state+40],r11d
 ret
_TimerFrameUpdate:
 ret
_TimerGetTimeStamp:
 mov eax,DWORD PTR [input+64]
 ret
Timer50Hz:
trap:
 mov edi,94
 mov eax,60
 syscall
_TimerSleep:
 jmp trap
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 mov esi,OFFSET FLAT:input
 add rsi,r8
 mov edx,68
 sub edx,r8d
 syscall
 test eax,eax
 jle finished
 add r8d,eax
 cmp r8d,68
 jne read_more
 mov rax,{GUARD}
 mov QWORD PTR [before],rax
 mov QWORD PTR [after],rax
 mov esi,OFFSET FLAT:input+16
 mov edi,OFFSET FLAT:state
 mov ecx,12
 rep movsd
 mov eax,DWORD PTR [input+8]
 mov BYTE PTR [DATA_008870],al
 mov eax,DWORD PTR [input+12]
 mov BYTE PTR [DATA_008835],al
 mov eax,DWORD PTR [input+64]
 sub eax,DWORD PTR [input+60]
 mov DWORD PTR [tmLastTime],eax
 mov eax,DWORD PTR [input+64]
 inc eax
 mov DWORD PTR [tmNext50Hz],eax
 mov eax,DWORD PTR [input]
 cmp eax,0
 je do_select
 cmp eax,1
 je do_play
 cmp eax,2
 je do_pause
 cmp eax,3
 jne trap
 call FUNC_001418
 jmp emit
do_select:
 call FUNC_000208
 jmp emit
do_play:
 call FUNC_000217
 jmp emit
do_pause:
 call FUNC_000220
emit:
 mov eax,1
 mov edi,1
 mov esi,OFFSET FLAT:before
 mov edx,64
 syscall
 jmp next_case
finished:
 mov eax,60
 xor edi,edi
 syscall
.section .data
DATA_007672: .quad gui_get
DATA_007673: .quad gui_set
tmMinFrame: .long 0
.section .bss
input: .zero 68
DATA_008870: .zero 1
DATA_008835: .zero 1
.balign 8
before: .zero 8
state: .zero 48
after: .zero 8
tmNext50Hz: .zero 4
.set DATA_009012,state
.set DATA_009013,state+4
.set DATA_007706,state+8
.set DATA_009123,state+12
.set DATA_008808,state+16
.set DATA_009155,state+20
.set DATA_009156,state+24
.set DATA_009157,state+28
.set tmLastTime,state+44
stack: .zero 65536
stack_end:
.section .note.GNU-stack,"",@progbits
"""
    return assembly, {str(number): sha(block.encode()) for number, block in zip(numbers, blocks)}


def make_cases() -> list[dict]:
    rows = []
    initial = [0x11223344, 0x55667788, 0xABCDEF01, 0x91ABCDEF, 0x3C22E, 0x12345678, 0xFFEEDDCC, 0x12345678, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0]
    for mode in [0, 2, 4, 0x24, 0x30, 0x34]:
        for action in list(range(256)):
            rows.append({"operation": 0, "action": action, "player_mode": mode, "input_flag": 0, "initial": initial, "elapsed_ms": 1, "timestamp": 1000})
    for timer in [0, 994, 9942, 99420, 994200, 9942000, 0xF880000]:
        for operation in [1, 2]:
            state = initial.copy()
            state[2] = timer
            rows.append({"operation": operation, "action": 0, "player_mode": 0, "input_flag": 255, "initial": state, "elapsed_ms": 1, "timestamp": 1000})
    rng = random.Random(1418208)
    for timer in [0] + TIMERS + [0xF880000]:
        for elapsed in [0, 1, 2, 19, 20, 21, 33, 100, 1000]:
            if elapsed * timer // 20 > 0xFFFFFFFF:
                continue
            for previous in [0, 0xFFFFFFFF, rng.getrandbits(32)]:
                state = initial.copy();state[2] = timer;state[6] = previous;state[7] = previous ^ 0xA5A5A5A5
                rows.append({"operation": 3, "action": 0, "player_mode": 0, "input_flag": 0, "initial": state, "elapsed_ms": elapsed, "timestamp": 1000000})
    return rows


def packet(row: dict) -> bytes:
    # input[60] overlaps initial last_timestamp intentionally: this word is
    # replaced by the source timer initialisation in the wrapper before entry.
    values = [row["operation"],row["action"],row["player_mode"],row["input_flag"]] + row["initial"]
    values[-1] = row["elapsed_ms"]
    values.append(row["timestamp"])
    return struct.pack("<17I", *values)


def main() -> None:
    path = Path("/workspace/ffe-upstream/jjffe/ffe.asm")
    raw = path.read_bytes()
    if sha(raw) != ASM_SHA:
        raise ValueError("Unexpected reviewed JJFFE assembly")
    assembly, procedure_hashes = make_assembly(raw.decode())
    rows = make_cases();payload = b"".join(map(packet, rows))
    with tempfile.TemporaryDirectory(prefix="source-time-native-") as temporary:
        work = Path(temporary);(work / "oracle.S").write_text(assembly)
        subprocess.run(["as","--64","-o",str(work / "oracle.o"),str(work / "oracle.S")],check=True)
        subprocess.run(["ld","-o",str(work / "oracle"),str(work / "oracle.o")],check=True)
        outputs = [subprocess.run([str(work / "oracle")],input=payload,capture_output=True,check=True,timeout=20).stdout for _ in range(3)]
        reverse = subprocess.run([str(work / "oracle")],input=b"".join(packet(row) for row in reversed(rows)),capture_output=True,check=True,timeout=20).stdout
    if len(set(outputs)) != 1 or len(outputs[0]) != len(rows) * 64:
        raise ValueError("Native output incomplete or unstable")
    packets = [outputs[0][i * 64:(i + 1) * 64] for i in range(len(rows))]
    if reverse != b"".join(reversed(packets)):
        raise ValueError("Native case order changes state")
    for row, output in zip(rows, packets):
        if struct.unpack_from("<Q",output)[0] != GUARD or struct.unpack_from("<Q",output,56)[0] != GUARD:
            raise ValueError("Time global guard changed")
        row["result"] = dict(zip(STATE_NAMES,struct.unpack_from("<12I",output,8)))
    report = {"schema":1,"source_assembly_sha256":ASM_SHA,"source_commit":"7e540341d4e09aa3c92877b87d49e7f2c143ad8d","procedures_sha256":procedure_hashes,"scope":"Actual F207/F208/F217/F220 and F1418 instructions in host ELF; GUI callbacks only record parameters, source Timer50Hz is held ahead of supplied timestamp and traps if entered. This is not full original frame/physics scheduling or Android x86 runtime.","host_abi_adaptations":["Existing reviewed 64-bit host stack/callback adapter","F208 jump table widened from4-byte to8-byte host code pointers with selector indices unchanged"],"case_count":len(rows),"fresh_process_runs":3,"reverse_repeat_cases":len(rows),"guards_unchanged":True,"adapted_assembly_sha256":sha(assembly.encode()),"input_sha256":sha(payload),"native_output_sha256":sha(outputs[0]),"cases":rows}
    destination = PROJECT / "tests/fixtures/source_time_controls_native.json"
    destination.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"case_count":len(rows),"fresh_process_runs":3,"guards_unchanged":True,"fixture_sha256":sha(destination.read_bytes())}))


if __name__ == "__main__":
    main()
