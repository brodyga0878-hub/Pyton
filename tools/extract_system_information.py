#!/usr/bin/env python3
"""Extract the DOS-authoritative FFE system-information text graph.

Pinned JJFFE labels locate source data; every emitted string and original
pointer is independently checked against the uploaded DOS executable. Labels
are not C-string bounds: DATA7182 also contains constructor names after its
first string. Source bytes, including blanks/control bytes, stay authoritative.
This tool does not implement runtime text expansion or invent missing strings.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import re
import struct

PROJECT = Path(__file__).resolve().parents[1]
EXE_SHA = "d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
ASM_SHA = "d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a"
DATA_SHA = "34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850"
COMMIT = "7e540341d4e09aa3c92877b87d49e7f2c143ad8d"
DOS_DATA_ADDRESS_DELTA = 0x416400
SOURCE_VARIANT = "dos-firstenc-system-information-texts-v1"


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


@dataclass(frozen=True)
class Block:
    label: int
    line: int
    body: str


def source_blocks(source: str) -> dict[int, Block]:
    # PLUS labels terminate a block too; they are not silently appended to a
    # preceding ordinary DATA label and misrepresented as one source object.
    pattern = re.compile(r"^DATA_(\d+)(?:_PLUS_\d+)?:[^\n]*\n", re.M)
    matches = list(pattern.finditer(source))
    result = {}
    for index, match in enumerate(matches):
        if "_PLUS_" in match[0]:
            continue
        number = int(match[1])
        end = matches[index + 1].start() if index + 1 < len(matches) else len(source)
        result[number] = Block(number, source.count("\n", 0, match.start()) + 1, source[match.end():end])
    return result


def uncomment(line: str) -> str:
    quote = ""
    for index, char in enumerate(line):
        if quote:
            if char == quote:
                quote = ""
        elif char in "'\"":
            quote = char
        elif char == ";":
            return line[:index].strip()
    return line.strip()


def tokens(text: str) -> list[str]:
    result, quote, start = [], "", 0
    for index, char in enumerate(text):
        if quote:
            if char == quote:
                quote = ""
        elif char in "'\"":
            quote = char
        elif char == ",":
            result.append(text[start:index].strip())
            start = index + 1
    if quote:
        raise ValueError("Unclosed source string")
    result.append(text[start:].strip())
    return result


def db_bytes(block: Block) -> bytes:
    result = bytearray()
    for original in block.body.splitlines():
        code = uncomment(original)
        if not code:
            continue
        if not code.startswith("db "):
            raise ValueError(f"DATA{block.label} is not a pure db block: {code}")
        for token in tokens(code[3:]):
            if token.startswith(("'", '"')):
                if token[-1] != token[0]:
                    raise ValueError("Unclosed source token")
                result.extend(token[1:-1].encode("latin1"))
            else:
                value = int(token, 0)
                if not 0 <= value <= 255:
                    raise ValueError(f"Non-byte source db token: {token}")
                result.append(value)
    return bytes(result)


def pointer_labels(block: Block) -> list[int]:
    result = []
    for original in block.body.splitlines():
        code = uncomment(original)
        if not code:
            continue
        match = re.fullmatch(r"dd DATA_(\d+)", code)
        if not match:
            raise ValueError(f"Unexpected pointer entry in DATA{block.label}: {code}")
        result.append(int(match[1]))
    return result


def unique_offset(executable: bytes, raw: bytes, name: str) -> int:
    at = executable.find(raw)
    if not raw or at < 0 or executable.find(raw, at + 1) >= 0:
        raise ValueError(f"Missing or ambiguous DOS bytes: {name}")
    return at


def cstring(raw: bytes) -> bytes:
    # F1348 consumes FF/FE operands and FD's one operand before checking the
    # next text byte for zero. This also preserves a zero-valued operand.
    at = 0
    while at < len(raw):
        value = raw[at]
        if value == 0:
            return raw[:at + 1]
        width = 3 if value in (0xFF, 0xFE) else (2 if value == 0xFD else 1)
        if at + width > len(raw):
            raise ValueError("Truncated source text control")
        at += width
    raise ValueError("Source string has no terminal NUL")


def text_controls(raw: bytes) -> dict:
    ff, fd, fe, extended, c0 = [], [], [], [], []
    at = 0
    while at < len(raw) - 1:
        value = raw[at]
        if value == 0xFF:
            ff.append((raw[at + 1] << 8) | raw[at + 2]); at += 3
        elif value == 0xFD:
            fd.append(raw[at + 1]); at += 2
        elif value == 0xFE:
            fe.append([raw[at + 1], raw[at + 2]]); at += 3
        else:
            if value >= 128:
                extended.append({"offset": at, "byte": value})
            elif value < 32 and value != 13:
                c0.append({"offset": at, "byte": value})
            at += 1
    return {"ff_refs": ff, "fd_operands": fd, "fe_operands": fe, "extended_bytes": extended, "c0_passthrough": c0}


def ascii_preview(raw: bytes) -> str:
    return "".join(chr(value) if 32 <= value < 127 else ("\\r" if value == 13 else f"\\x{value:02X}") for value in raw[:-1])


def extract(executable: bytes, asm_bytes: bytes, data_bytes: bytes, old_metadata: dict) -> dict:
    if (sha(executable), sha(asm_bytes), sha(data_bytes)) != (EXE_SHA, ASM_SHA, DATA_SHA):
        raise ValueError("Pinned DOS/JJFFE source SHA256 mismatch")
    source = data_bytes.decode("utf-8")
    assembly = asm_bytes.decode("utf-8")
    blocks = source_blocks(source)
    strings, groups, offsets = {}, [], {}

    def string_group(name: str, first: int, end: int) -> None:
        payloads = {label: db_bytes(blocks[label]) for label in range(first, end)}
        full = b"".join(payloads.values())
        absolute = unique_offset(executable, full, name)
        cursor = 0
        for label, payload in payloads.items():
            raw = cstring(payload)
            offsets[label] = absolute + cursor
            if executable[absolute + cursor:absolute + cursor + len(raw)] != raw:
                raise ValueError(f"DOS C-string mismatch DATA{label}")
            strings[str(label)] = {"hex": raw.hex(), "executable_offset": absolute + cursor,
                                  "byte_length": len(raw), "sha256": sha(raw), "ascii_preview": ascii_preview(raw),
                                  "blank": raw == b" \0", "assembly_line": blocks[label].line,
                                  "source_group": name, "label_payload_bytes": len(payload),
                                  "ignored_label_tail_bytes": len(payload) - len(raw), **text_controls(raw)}
            cursor += len(payload)
        groups.append({"id": name, "first_label": first, "exclusive_end_label": end,
                       "executable_offset": absolute, "bytes": len(full), "sha256": sha(full),
                       "matches_source_bytes": True, "cstring_bytes": sum(strings[str(n)]["byte_length"] for n in range(first, end))})

    string_group("system_strings_and_formats", 6830, 7104)
    string_group("system_long_descriptions_and_constructor_tail", 7139, 7183)
    string_group("commodity_and_mission_item_names", 6216, 6254)
    string_group("speed_unit_literals", 7653, 7655)
    lookup, tables = {}, {}
    for key, label, expected, base, bias in [
        ("system", 6796, list(range(6830, 7097)), 0x8401, 1),
        ("long", 7117, list(range(7139, 7183)), 0x8000, 0),
        ("commodity", 6162, list(range(6216, 6254)), 0x8E00, 0),
    ]:
        labels = pointer_labels(blocks[label])
        if labels != expected:
            raise ValueError(f"Unexpected DATA{label} source pointer order")
        pointers = [offsets[target] + DOS_DATA_ADDRESS_DELTA for target in labels]
        raw = struct.pack(f"<{len(pointers)}I", *pointers)
        at = unique_offset(executable, raw, f"DATA{label} DOS pointers")
        for index, target in enumerate(labels):
            lookup[str(base + index)] = str(target)
        tables[key] = {"data_label": label, "labels": labels, "ff_base": base,
                       "index_bias": bias, "executable_offset": at, "pointer_bytes": len(raw),
                       "pointer_sha256": sha(raw), "dos_pointer_u32": pointers,
                       "dos_address_policy": "verified DOS data linear VA = file offset +0x416400"}

    jjffe = b"".join(db_bytes(blocks[label]) for label in range(7106, 7117))
    dos = bytes.fromhex(old_metadata["dos_metadata_hex"])
    at = int(old_metadata["metadata_executable_offset"])
    if jjffe.hex() != old_metadata["metadata_hex"] or executable[at:at + len(dos)] != dos:
        raise ValueError("DOS/JJFFE metadata bytes do not match independently pinned resources")
    prefix = 18198
    if len(dos) != 18268 or len(jjffe) != 18808 or jjffe != dos[:prefix] + jjffe[prefix:prefix + 540] + dos[prefix:]:
        raise ValueError("Unexpected JJFFE ten-row insertion boundary")
    exceptions = list(struct.unpack("<4I", dos[-16:]))
    if exceptions != old_metadata["source_exception_ids"]:
        raise ValueError("F868 exception IDs differ")
    records = dos[:-16]
    known = [struct.unpack_from("<I", records, 432 + index * 54)[0] for index in range(330)]
    if known[-1] != 0 or any(value == 0 for value in known[:-1]):
        raise ValueError("DOS F868 scan/sentinel boundary differs")

    def category(base: int, count: int) -> dict:
        return {"ff_base": base, "ff_codes": list(range(base, base + count)),
                "labels": [lookup[str(code)] for code in range(base, base + count)]}

    dispatch_match = re.search(r"^DATA_007652_PLUS_52:[^\n]*\n(.*?)(?=^DATA_\d+:)", source, re.M | re.S)
    if dispatch_match is None:
        raise ValueError("Missing original FF30 source dispatch")
    dispatch_names = re.findall(r"^\s*dd (FUNC_\d+_[A-Za-z0-9_]+)\s*$", dispatch_match[1], re.M)
    if len(dispatch_names) != 42:
        raise ValueError("FF30 source dispatch bound differs")
    source_dispatch = {str(0x3000 + index): name for index, name in enumerate(dispatch_names)}
    unresolved = []
    variable_codes = {0x3001, 0x3002, 0x3003, 0x3005, 0x3007, 0x3008, 0x300A, 0x3016, 0x3017, 0x3018, 0x3019, 0x301A, 0x301B, 0x301F}
    for label, row in strings.items():
        for code in row["ff_refs"]:
            if str(code) not in lookup and code not in variable_codes:
                unresolved.append({"data_label": int(label), "code": code, "reason": "No extracted literal or declared source-variable handler; runtime must report unsupported."})
    long_raw = b"".join(bytes.fromhex(strings[str(n)]["hex"]) for n in range(7139, 7183))
    blanks = [0x8000 + n - 7139 for n in range(7139, 7183) if strings[str(n)]["blank"]]
    if len(long_raw) != 6333 or len(blanks) != 19:
        raise ValueError("Long text C-string boundary/blank count differs")
    functions = {}
    for number in [77, 613, 830, 831, 832, 842, 843, 854, 863, 868, 869, 870, 895, 1343, 1344, 1347, 1348, 1371, 1377, 1544, 1545]:
        match = re.search(rf"^FUNC_{number:06d}(?:_[A-Za-z0-9_]+)?:[^\n]*\n.*?(?=^FUNC_\d+(?:_[A-Za-z0-9_]+)?:|\Z)", assembly, re.M | re.S)
        if match is None:
            raise ValueError(f"Missing pinned source procedure F{number}")
        functions[str(number)] = {"assembly_line": assembly.count("\n", 0, match.start()) + 1,
                                  "source_text_sha256": sha(match[0].encode("utf-8")),
                                  "address_domain": "JJFFE source text/labels; comment Pos is not a DOS executable file offset"}
    return {
        "schema": 1, "source_variant": SOURCE_VARIANT, "source_sha256": EXE_SHA,
        "source_assembly_sha256": ASM_SHA, "source_data_sha256": DATA_SHA, "source_commit": COMMIT,
        "scope": "DOS-verified system short/long/body/type/unit/trade text graph; original bytes/pointers, not a completed text interpreter or page renderer.",
        "string_key_format": "decimal DATA label", "ff_key_format": "decimal unsigned16 FF code",
        "string_encoding_policy": "Original byte stream including terminal NUL. ASCII preview is escaped diagnostics only; unknown extended glyphs are not assigned a guessed encoding.",
        "strings": strings, "ff_code_to_label": lookup, "pointer_tables": tables, "source_blocks": groups,
        "categories": {"government": category(0x84CB, 16), "economy": category(0x84BB, 16),
                       "allegiance": category(0x84B7, 4), "population": category(0x84DB, 10),
                       "body_type": category(0x8476, 35), "stellar_class": category(0x8488, 14),
                       "multiplicity": category(0x8499, 5), "trade_commodities": category(0x8E00, 33),
                       "extra_mission_items": category(0x8E21, 5)},
        "long_descriptions": {"count": 44, "text_count": 25, "blank_count": 19, "blank_ff_codes": blanks,
                              "executable_offset": offsets[7139], "cstring_bytes": len(long_raw), "cstring_sha256": sha(long_raw),
                              "data7182_first_string_hex": strings["7182"]["hex"], "constructor_name_tail_bytes": strings["7182"]["ignored_label_tail_bytes"],
                              "audit_correction": "Earlier26text/18blank counted all DATA7182 constructor-name tail as a description. Original F895/F1348 consumes only the first string, so25/19 is authoritative."},
        "metadata_variant": "dos-original-info-only", "dos_metadata_hex": dos.hex(), "dos_metadata_sha256": sha(dos),
        "metadata_stride_bytes": 54, "negative_rows": 8, "dos_handcoded_count": 329, "dos_scan_rows": 330,
        "dos_record_rows": 338, "dos_record_table_bytes": len(records), "dos_sentinel_offset": prefix,
        "dos_metadata_executable_offset": at, "dos_exception_ids_offset": len(records), "source_exception_ids": exceptions,
        "metadata_variants": {"selected": "uploaded-DOS-FIRSTENC.EXE", "live_world_existing_variant": "jjffe-7e54034-policy-table-with10-added-rows",
                              "jjffe_hex": jjffe.hex(), "jjffe_sha256": sha(jjffe), "unchanged_dos_prefix_bytes": prefix,
                              "jjffe_inserted_rows": 10, "jjffe_inserted_bytes_hex": jjffe[prefix:prefix + 540].hex(),
                              "difference_policy": "Use DOS metadata for information queries only; never silently replace the existing world's JJFFE policy/resource or claim source variants identical."},
        "page_contracts": {"F842": {"known_count_ff": 0x84A0, "unknown_ff": 0x84B3, "long_description_variable": "DATA_008961", "known_state": "DATA_008962 !=0"},
                           "F843": {"overview_action": 255, "demographics_action": 250, "trade_action": 249, "body_action_first": 128, "body_action_last": 188,
                                    "government": "FF84CB+(political_word&63)", "economy": "FF84BB+(political_word&63)", "allegiance": "FF84B7+(political_word>>6)",
                                    "population": "FF84DB+F870 byte(record+4); not F869 byte(record+5)", "body_type": "FF8476+type_code", "trade_count": 33,
                                    "trade_flags": "For each commodity0..32: byte&0x80 ->illegal first; else byte&7>=5 ->major,>=3 ->minor; byte&8 ->export,otherwise import."},
                           "F863": {"distance_ff": 0x849E, "description_variable": "DATA_008960", "literal_labels": [7101, 7102, 7103]},
                           "F895": {"pointer_table": 7117, "index": "ff_code&0x1ff", "index_bias": 0}},
        "dependency_graph": {"source_variable_ff_codes": sorted(variable_codes), "unresolved_ff_references": unresolved,
                             "extended_glyphs": [{"data_label": int(label), **item} for label, row in strings.items() for item in row["extended_bytes"]],
                             "c0_passthrough": [{"data_label": int(label), **item} for label, row in strings.items() for item in row["c0_passthrough"]],
                             "source_ff30_dispatch": source_dispatch,
                             "dispatch_provenance": "Pinned JJFFE DATA7652_PLUS_52 dispatch names and indices, not a claim that every handler is already implemented by the runtime. Numeric/tons handlers build punctuation/unit t inline; no guessed text resource is substituted.",
                             "unsupported_policy": "Preserve/report unsupported refs/glyphs; do not fabricate descriptions, defaults, encodings, units or market commodities."},
        "assembly_functions": functions,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exe", type=Path, default=Path("/workspace/ffe-original/FIRSTENC.EXE"))
    parser.add_argument("--asm", type=Path, default=Path("/workspace/ffe-upstream/jjffe/ffe.asm"))
    parser.add_argument("--data", type=Path, default=Path("/workspace/ffe-upstream/jjffe/ffedat.asm"))
    parser.add_argument("--output", type=Path, default=PROJECT / "data/ffe_system_information.json")
    args = parser.parse_args()
    old = json.loads((PROJECT / "data/ffe_system_metadata.json").read_text())
    result = extract(args.exe.read_bytes(), args.asm.read_bytes(), args.data.read_bytes(), old)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(f"SYSTEM INFORMATION EXTRACT: {len(result['strings'])} DOS-verified strings, {len(result['ff_code_to_label'])} FF mappings;44long=25text+19blank;DOS329known+8negative+sentinel")


if __name__ == "__main__":
    main()
