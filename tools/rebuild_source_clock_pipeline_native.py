#!/usr/bin/env python3
"""Prove and execute uploaded DOS frame-clock admission in a host-only ELF.

Reassembled32-bit GAS must match all143 uploaded original bytes. Its reviewed
ELF64 execution adapter widens call/stack slots, replaces only three ESP+8
cleanups byRSP+16 and retains the original32-bit arithmetic. F148 is a
preserving event recorder; RET is appended at the reviewed slice boundary.
No Python expected clock, deadline, carry or event transition is used.
This is not JJFFE F1418 timing, full F148 dispatch or large-step physics.

Default execution replays the SHA-pinned captured proof material included in
the source archive; private retail/JJFFE files are not needed. Use the explicit
--refresh-original-proof option to compare a fresh original executable again.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import random
import re
import struct
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[1]
EXE_SHA = "d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
ASM_SHA = "d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a"
START = 0x2D3C8
END = 0x2D457
VA = 0x43C5C8
GUARD = 0x434C4F434B444F53
INPUT_BYTES = 36
OUTPUT_BYTES = 256
FIELDS = ["clock_low_u32", "clock_day_u32", "deadline_low_u32", "deadline_day_u32",
          "accelerated_counter_u32", "frame_ticks_u32", "system_counter_u32",
          "system_frame_ticks_u32", "system_total_u32"]
PROOF_DIR = PROJECT / "validation/reference-bank-2026-11-17/clock-native-proof"
ORIGINAL_BLOCK_SHA = "aeff4e4e945fcbfd39c2635e4537e0d7ffe736656108d0600f74be55e2a206d4"
PROOF_PINS = {
    "clock-source32.S": "c796cd1b90e4aebcb3a9d74ea8b7d0553e6532d39971f29aee17e925d397a7c9",
    "clock-observed.S": "91b6c187d805f0adb7498d50a76f36d7177243df65949028434d3808e73c8edb",
    "clock-observed.ld": "5a5f1fd07587ca54913d4b56bf04343480ed65524cd8b07da594b2179fc270a4",
    "dos-clock-admission.txt": "eebc50f8ab7383a90462e7bdeb8ebc5cdc4a16a90cab28eeb7519a2c65cd295e",
    "jjffe-clock-admission-reference.asm": "31624900cc6298a2a920945535a188d535894f736bc88bd7a17ede2adfe9594f",
}
SOURCE32_HEADER = '.intel_syntax noprefix\n.code32\n.section .clock,"ax"\n.equ event_recorder,0x41942c\n'


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def original_assembly(executable: Path) -> tuple[str, str]:
    disassembly = subprocess.check_output(["objdump", "-d", "-Mintel", "--no-show-raw-insn", "--start-address=" + hex(VA), "--stop-address=" + hex(VA + END - START), str(executable)], text=True)
    parsed = []
    for line in disassembly.splitlines():
        match = re.match(r"^\s*([0-9a-f]+):\s+(.*?)\s*$", line)
        if match:
            parsed.append((int(match[1], 16), match[2]))
    if not parsed or parsed[0][0] != VA:
        raise ValueError("Missing original DOS disassembly")
    lines = []
    for address, instruction in parsed:
        lines.append(".Ldos_%x:" % address)
        branch = re.fullmatch(r"(j[a-z]+|call)\s+0x([0-9a-f]+)", instruction)
        if branch:
            target = int(branch[2], 16)
            if VA <= target < VA + END - START:
                instruction = branch[1] + " .Ldos_%x" % target
            elif branch[1] == "call" and target == 0x41942c:
                instruction = "call event_recorder"
            else:
                raise ValueError("Unreviewed outgoing clock branch: " + instruction)
        # Preserve the original alternative register-register opcode encoding.
        # Both encodings disassemble identically; pin the uploaded bytes anyway.
        alternatives = {"cmp    esi,ecx": ".byte 0x3b,0xf1", "mov    eax,ecx": ".byte 0x8b,0xc1", "xor    edx,edx": ".byte 0x33,0xd2"}
        lines.append(" " + alternatives.get(instruction, instruction))
    return "\n".join(lines) + "\n", disassembly


def assembly(executable: Path, body32: str) -> str:
    if any(char in str(executable) for char in '"\n\r'):
        raise ValueError("Unsafe incbin filename")
    initial = """
.intel_syntax noprefix
.code64
.section .recorder,"ax"
event_recorder:
 pushfq
 push rax
 push rbx
 push rcx
 push rdx
 push rsi
 push rdi
 push rbp
 mov edx,DWORD PTR [output+44]
 cmp edx,3
 jae failed
 mov eax,DWORD PTR [rsp+72]
 mov ecx,DWORD PTR [rsp+80]
 mov DWORD PTR [output+48+edx*8],eax
 mov DWORD PTR [output+52+edx*8],ecx
 inc DWORD PTR [output+44]
 pop rbp
 pop rdi
 pop rsi
 pop rdx
 pop rcx
 pop rbx
 pop rax
 popfq
 ret
.section .clock,"ax"
clock_entry:
"""
    host_body = body32.replace('add    esp,0x8', 'add    rsp,0x10')
    if host_body.count('rsp,0x10') != 3 or 'esp,' in host_body:
        raise ValueError('Unreviewed source stack adjustments')
    initial += host_body + ' ret\n'
    initial += """
.section .systemtotal,"aw",@nobits
systemtotal_before: .zero 8
system_total: .zero 4
systemtotal_after: .zero 8
.section .game,"aw",@nobits
game_before: .zero 8
game: .zero 128
game_after: .zero 8
.section .systemframe,"aw",@nobits
systemframe_before: .zero 8
system_frame: .zero 4
systemframe_after: .zero 8
.section .raw,"aw",@nobits
raw_before: .zero 8
frame_ticks: .zero 4
accelerated_counter: .zero 4
system_counter: .zero 4
raw_after: .zero 8
.section .text,"ax"
.global _start
_start:
 mov esp,OFFSET FLAT:stack_end
next_case:
 xor r8d,r8d
read_more:
 xor eax,eax
 xor edi,edi
 lea rsi,[input+r8]
 mov edx,36
 sub edx,r8d
 syscall
 test eax,eax
 js failed
 jnz got_input
 test r8d,r8d
 jnz failed
 mov eax,60
 xor edi,edi
 syscall
got_input:
 add r8d,eax
 cmp r8d,36
 jb read_more
 mov edi,OFFSET FLAT:output
 xor eax,eax
 mov ecx,256
 rep stosb
 mov edi,OFFSET FLAT:game
 mov eax,0xa5
 mov ecx,128
 rep stosb
"""
    for name in ("systemtotal_before", "systemtotal_after", "game_before", "game_after",
                 "systemframe_before", "systemframe_after", "raw_before", "raw_after",
                 "output", "output+248"):
        initial += f" mov DWORD PTR [{name}],0x{GUARD & 0xffffffff:08x}\n mov DWORD PTR [{name}+4],0x{GUARD >> 32:08x}\n"
    locations = ["game", "game+4", "game+0x76", "game+0x7a", "accelerated_counter",
                 "frame_ticks", "system_counter", "system_frame", "system_total"]
    for index, location in enumerate(locations):
        initial += f" mov eax,DWORD PTR [input+{index * 4}]\n mov DWORD PTR [{location}],eax\n"
    initial += " mov ebx,OFFSET FLAT:game\n call clock_entry\n"
    for name in ("systemtotal_before", "systemtotal_after", "game_before", "game_after",
                 "systemframe_before", "systemframe_after", "raw_before", "raw_after"):
        initial += f" cmp DWORD PTR [{name}],0x{GUARD & 0xffffffff:08x}\n jne failed\n cmp DWORD PTR [{name}+4],0x{GUARD >> 32:08x}\n jne failed\n"
    for index, location in enumerate(locations):
        initial += f" mov eax,DWORD PTR [{location}]\n mov DWORD PTR [output+{8 + index * 4}],eax\n"
    initial += """
 mov esi,OFFSET FLAT:game
 mov edi,OFFSET FLAT:output+72
 mov ecx,128
 rep movsb
 xor r8d,r8d
write_more:
 mov eax,1
 mov edi,1
 lea rsi,[output+r8]
 mov edx,256
 sub edx,r8d
 syscall
 test eax,eax
 jle failed
 add r8d,eax
 cmp r8d,256
 jb write_more
 jmp next_case
failed:
 mov eax,60
 mov edi,93
 syscall
.section .bss,"aw",@nobits
input: .zero 36
output: .zero 256
stack: .zero 65536
stack_end:
.section .note.GNU-stack,"",@progbits
"""
    return initial


LINKER = """ENTRY(_start)
SECTIONS {
 . = 0x41942c; .recorder : { *(.recorder) }
 . = 0x43c5c8; .clock : { *(.clock) }
 . = 0x638898; .systemtotal : { *(.systemtotal) }
 . = 0x642134; .game : { *(.game) }
 . = 0x6476a0; .systemframe : { *(.systemframe) }
 . = 0x652c04; .raw : { *(.raw) }
 . = 0x700000; .text : { *(.text) }
 . = 0x710000; .bss : { *(.bss) }
 /DISCARD/ : { *(.note.GNU-stack) }
}
"""


def cases() -> list[dict]:
    result = []
    base = dict(zip(FIELDS, [0x80000000, 0x121CF7, 0xFFFFFFFF, 0xFFFFFFFF,
                            0, 0xA5A5A5A5, 0, 0x5A5A5A5A, 0x12345678]))

    def add(domain: str, **changes: int) -> None:
        row = {**base, **changes}
        result.append({"id": len(result), "domain": domain, "initial": row})

    for low in [0, 1, 0x7FFFFFFF, 0x80000000, 0xFFFFFFFE, 0xFFFFFFFF]:
        for ticks in [0, 1, 2, 49710, 0x7FFFFFFF, 0x80000000, 0xFFFFFFFF]:
            for day in [0, 6, 7, 0x121CF7, 0xFFFFFFFE, 0xFFFFFFFF]:
                add("unsigned_carry_day_wrap", clock_low_u32=low, clock_day_u32=day,
                    accelerated_counter_u32=ticks, system_counter_u32=ticks,
                    system_total_u32=0xFFFFFFFF)
    for day_delta in [-1, 0, 1, 7]:
        for low_delta in [-1, 0, 1]:
            for ticks in [0, 1, 49710, 0xFFFFFFFF]:
                add("dos_deadline_and_event_order", clock_low_u32=1000 + low_delta,
                    clock_day_u32=14 + day_delta, deadline_low_u32=1000,
                    deadline_day_u32=14, accelerated_counter_u32=ticks,
                    system_counter_u32=0xFFFF0000)
    for low, day, dl, dd in [(0, 15, 1, 14), (1, 15, 1, 14), (0xFFFFFFFF, 14, 0, 14),
                             (0, 0xFFFFFFFF, 0, 0xFFFFFFFF), (0, 0, 0, 0),
                             (0xFFFFFFFF, 0xFFFFFFFF, 0, 0), (0, 21, 0, 14),
                             (0, 20, 0, 21), (0xFFFFFFFF, 13, 0, 14)]:
        add("literal_dos_jjffe_deadline_difference", clock_low_u32=low,
            clock_day_u32=day, deadline_low_u32=dl, deadline_day_u32=dd)
    rng = random.Random(0xD05C10C)
    for _ in range(512):
        add("seeded_all_unsigned_fields", **{name: rng.getrandbits(32) for name in FIELDS})
    return result


def packet(row: dict) -> bytes:
    initial = row.get("initial")
    if not isinstance(initial, dict) or set(initial) != set(FIELDS) or any(
            type(initial[name]) is not int or not 0 <= initial[name] <= 0xFFFFFFFF for name in FIELDS):
        raise ValueError("Native input requires exactly nine unsigned32 integers")
    return struct.pack("<9I", *(row["initial"][name] for name in FIELDS))


def decode(raw: bytes, row: dict) -> dict:
    if len(raw) != OUTPUT_BYTES or struct.unpack_from("<Q", raw)[0] != GUARD or struct.unpack_from("<Q", raw, 248)[0] != GUARD:
        raise ValueError("Output canary changed")
    state = dict(zip(FIELDS, struct.unpack_from("<9I", raw, 8)))
    count = struct.unpack_from("<I", raw, 44)[0]
    if count > 3:
        raise ValueError("Unexpected callback count")
    events = [dict(zip(["event_u32", "param_u32"], struct.unpack_from("<2I", raw, 48 + index * 8))) for index in range(count)]
    # Check the complete original128-byte context for unrelated writes. Only
    # raw low/day and deadline-day may be changed by this actual source slice.
    before = bytearray([0xA5] * 128)
    for name, offset in [("clock_low_u32", 0), ("clock_day_u32", 4),
                         ("deadline_low_u32", 0x76), ("deadline_day_u32", 0x7A)]:
        struct.pack_into("<I", before, offset, row["initial"][name])
    mutable = set(range(8)) | set(range(0x7A, 0x7E))
    if any(raw[72 + i] != before[i] for i in range(128) if i not in mutable):
        raise ValueError("Unrelated original game-context byte changed")
    if raw[48 + count * 8:72] != bytes(24 - count * 8) or raw[200:248] != bytes(48):
        raise ValueError("Output padding changed")
    return {"state_after": state, "events": events}


def proof_material(args: argparse.Namespace) -> tuple[str, str, str, str, str, bytes | None]:
    if args.refresh_original_proof:
        executable = args.executable.resolve()
        original = executable.read_bytes()
        source = args.source.read_bytes()
        if sha(original) != EXE_SHA or sha(source) != ASM_SHA:
            raise ValueError("Unreviewed original executable or JJFFE source")
        block = original[START:END]
        if len(block) != 143 or sha(block) != ORIGINAL_BLOCK_SHA or original.find(block) != START or original.find(block, START + 1) >= 0:
            raise ValueError("Original clock slice identity or unique bounds differ")
        body32, disassembly = original_assembly(executable)
        source_text = assembly(executable, body32)
        reviewed_source = source.decode()
        excerpt_start = reviewed_source.index("\tJUMP_003850:")
        excerpt_end = reviewed_source.index("; Update frame/flip counts", excerpt_start)
        excerpt = reviewed_source[excerpt_start:excerpt_end]
        return body32, source_text, LINKER, disassembly, excerpt, block
    captured = {}
    for name, digest in PROOF_PINS.items():
        raw = (args.proof_dir / name).read_bytes()
        if sha(raw) != digest:
            raise ValueError("Captured original clock proof changed: " + name)
        # Preserve CRLF in the exact JJFFE excerpt; Path.read_text() would
        # silently normalize it and alter the frozen captured proof bytes.
        captured[name] = raw.decode("utf-8")
    source32 = captured["clock-source32.S"]
    if not source32.startswith(SOURCE32_HEADER) or not source32.endswith("ret\n"):
        raise ValueError("Unreviewed captured source32 wrapper")
    body32 = source32[len(SOURCE32_HEADER):-len("ret\n")]
    if assembly(Path("captured-proof"), body32) != captured["clock-observed.S"] or LINKER != captured["clock-observed.ld"]:
        raise ValueError("Captured source32 to host ABI adaptation differs")
    return body32, captured["clock-observed.S"], captured["clock-observed.ld"], captured["dos-clock-admission.txt"], captured["jjffe-clock-admission-reference.asm"], None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--executable", type=Path, default=Path("/workspace/ffe-original/FIRSTENC.EXE"))
    parser.add_argument("--source", type=Path, default=Path("/workspace/ffe-upstream/jjffe/ffe.asm"))
    parser.add_argument("--refresh-original-proof", action="store_true", help="Explicitly recheck pinned private original EXE and JJFFE source; otherwise replay included captured proof files")
    parser.add_argument("--proof-dir", type=Path, default=PROOF_DIR)
    parser.add_argument("--output", type=Path, default=PROJECT / "tests/fixtures/source_clock_pipeline_native.json")
    parser.add_argument("--validation-dir", type=Path, default=PROJECT / "validation/reference-bank-2026-11-17/clock-native-proof")
    args = parser.parse_args()
    body32, source_text, linker_text, disassembly, jjffe_clock_excerpt, block = proof_material(args)
    rows = cases()
    args.validation_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="clock-pipeline-native-") as temporary:
        work = Path(temporary)
        (work / "original32.s").write_text(SOURCE32_HEADER + body32 + "ret\n")
        subprocess.run(["as", "--32", "-o", str(work / "original32.o"), str(work / "original32.s")], check=True)
        subprocess.run(["ld", "-m", "elf_i386", "--section-start=.clock=" + hex(VA), "-e", hex(VA), "-o", str(work / "original32"), str(work / "original32.o")], check=True)
        subprocess.run(["objcopy", "-O", "binary", "--only-section=.clock", str(work / "original32"), str(work / "original32.bin")], check=True)
        reconstructed = (work / "original32.bin").read_bytes()
        if len(reconstructed) != 144 or reconstructed[-1:] != b"\xc3" or sha(reconstructed[:-1]) != ORIGINAL_BLOCK_SHA or (block is not None and reconstructed != block + b"\xc3"):
            raise ValueError("Reassembled32-bit clock instructions differ from original bytes")
        block = reconstructed[:-1]
        (work / "oracle.s").write_text(source_text)
        (work / "oracle.ld").write_text(linker_text)
        subprocess.run(["as", "--64", "-o", str(work / "oracle.o"), str(work / "oracle.s")], check=True)
        subprocess.run(["ld", "-m", "elf_x86_64", "-T", str(work / "oracle.ld"), "-o", str(work / "oracle"), str(work / "oracle.o")], check=True)
        subprocess.run(["objcopy", "-O", "binary", "--only-section=.clock", str(work / "oracle"), str(work / "clock.bin")], check=True)
        adapted_clock_sha = sha((work / "clock.bin").read_bytes())

        def execute(items: list[dict]) -> bytes:
            payload = b"".join(packet(row) for row in items)
            output = subprocess.run([str(work / "oracle")], input=payload, capture_output=True, check=True, timeout=20).stdout
            if len(output) != len(items) * OUTPUT_BYTES:
                raise ValueError("Native output incomplete")
            return output

        payload = b"".join(packet(row) for row in rows)
        outputs = [execute(rows) for _ in range(3)]
        if len(set(outputs)) != 1:
            raise ValueError("Fresh native processes disagree")
        packets = [outputs[0][i * OUTPUT_BYTES:(i + 1) * OUTPUT_BYTES] for i in range(len(rows))]
        if execute(list(reversed(rows))) != b"".join(reversed(packets)):
            raise ValueError("Case order changes source state")
        for row, raw in zip(rows, packets):
            row["result"] = decode(raw, row)
        sequences = []
        for name, first, additions in [
            ("rollover_then_empty_and_system_wrap", {"clock_low_u32": 0xFFFFFFFE, "clock_day_u32": 6}, [2, 0, 49710, 0, 0xFFFFFFFF, 1]),
            ("deadline_then_zero_replay", {"clock_low_u32": 999, "clock_day_u32": 14, "deadline_low_u32": 1000, "deadline_day_u32": 14}, [1, 0, 1, 0, 49710]),
            ("day_word_wrap", {"clock_low_u32": 0xFFFFFFFE, "clock_day_u32": 0xFFFFFFFF}, [2, 0, 1, 0xFFFFFFFF]),
        ]:
            current = {**rows[0]["initial"], **first}
            sequence = []
            for index, addition in enumerate(additions):
                initial = {**current, "accelerated_counter_u32": addition, "system_counter_u32": (index * 49710) & 0xFFFFFFFF}
                row = {"id": len(rows), "domain": "actual_native_sequence", "sequence_id": name, "sequence_step": index, "initial": initial}
                raw = execute([row])
                row["result"] = decode(raw, row)
                current = row["result"]["state_after"]
                sequence.append(row["id"])
                rows.append(row)
            sequences.append({"name": name, "case_ids": sequence, "state_after_used_as_next_initial": True})
        all_output = execute(rows)
        if any(decode(all_output[i * OUTPUT_BYTES:(i + 1) * OUTPUT_BYTES], row) != row["result"] for i, row in enumerate(rows)):
            raise ValueError("Independent full-bank replay differs")
        if execute(list(reversed(rows))) != b"".join(all_output[i * OUTPUT_BYTES:(i + 1) * OUTPUT_BYTES] for i in reversed(range(len(rows)))):
            raise ValueError("Full-bank reverse replay differs")
    report = {
        "schema": "starfrontier-source-clock-pipeline-native-v1", "reference": "uploaded DOS FIRSTENC.EXE",
        "executable_sha256": EXE_SHA, "reviewed_jjffe_assembly_sha256": ASM_SHA,
        "state_fields": FIELDS, "case_count": len(rows), "sequences": sequences,
        "byte_instruction_proofs": {"DOS_main_clock_admission": {"executable_offset": START, "virtual_address": VA,
            "byte_length": len(block), "sha256": sha(block), "source32_reassembled_bytes_identical": True, "instruction_count": len(re.findall(r"^\s*[0-9a-f]+:", disassembly, re.M)),
            "host_adaptation": "Source32 GAS reconstructs all143 uploaded bytes exactly. HostELF64 changes only three two-argument stack cleanups ESP+8 toRSP+16 and stack/call widths, retaining32-bit arithmetic and valid low pointers; F148 recorder preservesregisters/flags. AppendedRET at reviewed slice end."}},
        "known_dos_jjffe_differences": [
            {"branch": "deadline", "DOS": "day>=deadline_day AND low>=deadline_low", "JJFFE": "day>deadline_day OR(day==deadline_day AND low>=deadline_low)", "jjffe_comment": "FIX: Groundhog day bug"},
            {"branch": "maximum_date", "DOS": "No max-date F918 callback in this original slice", "JJFFE": "F918(1) when carried day exceeds0x127c8e"},
            {"branch": "millisecond_timer", "DOS": "Not executed by this slice", "JJFFE": "F1418_TimerAdvance is a separately rewritten host timer; existing1736controls do not establish DOS scheduler identity"},
        ],
        "native_execution": {"format": "host-only fixed-VA ELF64 after reviewed stack/call adaptation", "no_x86_in_android": True,
            "initial_bank_identical_fresh_processes": 3, "full_bank_replay": True,
            "reverse_case_order_identical": True, "all_context_and_global_canaries_unchanged": True,
            "all_unrelated_context_bytes_unchanged": True, "expected_transitions_computed_by_python": False,
            "assembly_sha256": sha(source_text.encode()), "adapted_clock_bytes_sha256": adapted_clock_sha, "linker_sha256": sha(LINKER.encode()),
            "initial_input_sha256": sha(payload), "full_output_sha256": sha(all_output)},
        "scope": ["Raw frame counter consumption, unsigned clock-low carry and day-word wrap, original DOS deadline predicate, ordered event21/16/15 recorder calls, system counter consumption and total wrap.",
                  "Callbacks are observed broadcasts only. Full F148 handler dispatch, F152 whole-second events, F149 object cadence, actual physics/AI/fuel/heat/collision, player frame selection, input50Hz and F1418 wall timing are outside this proof.",
                  "A raw32-bit accelerated counter carries at most one day per admission; this does not authorize dropping intermediate world events through arbitrarily multiplied dt."],
        "cases": rows}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    for name, raw in [("clock-source32.S", SOURCE32_HEADER + body32 + "ret\n"), ("clock-observed.S", source_text), ("clock-observed.ld", linker_text), ("dos-clock-admission.txt", disassembly), ("jjffe-clock-admission-reference.asm", jjffe_clock_excerpt)]:
        (args.validation_dir / name).write_text(raw)
    (args.validation_dir / "validation.json").write_text(json.dumps({k: v for k, v in report.items() if k != "cases"}, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"case_count": len(rows), "fixture_sha256": sha(args.output.read_bytes()), "mode": "fresh-original-byte-proof" if args.refresh_original_proof else "portable-captured-proof-replay",
                      "exact_original_bytes": len(block), "native_sequences": len(sequences),
                      "all_canaries_and_unrelated_bytes_unchanged": True}))


if __name__ == "__main__":
    main()
