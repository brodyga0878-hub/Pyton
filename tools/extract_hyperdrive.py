#!/usr/bin/env python3
"""Extract DOS-authoritative FFE hyperdrive tables and explicit session adapters.

No physics is implemented here. Source labels locate data, DOS bytes decide its
contents. In particular DATA7187+8 is F902's capacity threshold, not the drive's
installed mass. New-session adapters are labelled separately from F998 starts.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import struct

from extract_system_information import (
    ASM_SHA, COMMIT, DATA_SHA, DOS_DATA_ADDRESS_DELTA, EXE_SHA,
    db_bytes, sha, source_blocks, unique_offset,
)

PROJECT = Path(__file__).resolve().parents[1]
PROFILE = "dos-firstenc-hyperdrive-tables-v1"
EQUIPMENT_DIFFERENCES = [(1185, 235, 215), (1207, 235, 215),
                         (1229, 235, 215), (1251, 235, 215)]
CODE_ANCHORS = {
    "F998_selector1_equipment": (0x30E88, "c683d000000002c683d200000088c783c800000000002440c683d600000082c683d700000082"),
    "F998_selector1_capacity": (0x30EAE, "832d5422640010"),
    "F998_selector1_hydrogen": (0x30EB5, "66c705962264000100"),
    "F998_selector1_cargo_used": (0x30EBE, "c7055c22640001000000"),
    "F998_selector3_equipment": (0x30D78, "c683d000000003c683d200000088c683d600000082c683d700000082c683d800000082c683d90000008266c783e20000000000c783c800000000000400"),
    "F998_selector3_capacity": (0x30DB5, "832d542264001f"),
    "F998_selector3_jetfuel": (0x30DC6, "c7831e01000000000040"),
    "F998_selector3_hydrogen": (0x30DD0, "66c705962264000400"),
    "F998_selector3_cargo_used": (0x30DD9, "c7055c22640004000000"),
    "F1533_builtin_drive": (0x446CD, "668b72146685f67d128bd68893d00000000fbed22b04951cea4e0066898316010000"),
}


def extract(executable: bytes, asm_bytes: bytes, data_bytes: bytes,
            registry: dict) -> dict:
    if (sha(executable), sha(asm_bytes), sha(data_bytes)) != (EXE_SHA, ASM_SHA, DATA_SHA):
        raise ValueError("Pinned DOS/JJFFE source SHA256 mismatch")
    if registry.get("source_sha256") != EXE_SHA:
        raise ValueError("Ship registry is not from the pinned DOS executable")
    code_anchors = {}
    for name, (at, encoded) in CODE_ANCHORS.items():
        raw = bytes.fromhex(encoded)
        if executable[at:at + len(raw)] != raw:
            raise ValueError(f"DOS instruction anchor mismatch: {name}")
        code_anchors[name] = {"dos_file_offset": at, "hex": encoded,
                              "byte_count": len(raw), "sha256": sha(raw)}
    blocks = source_blocks(data_bytes.decode("utf-8"))
    tables = {}

    def table(key: str, first: int, end: int, stride: int, consumers: list[str]) -> bytes:
        raw = b"".join(db_bytes(blocks[label]) for label in range(first, end))
        anchor, anchor_end = raw, end
        # Some tables intentionally share a prefix (DATA6261 and DATA7210).
        # Locate through the following source bytes, retaining exact bounds.
        while True:
            try:
                at = unique_offset(executable, anchor, key)
                break
            except ValueError:
                if anchor_end >= end + 4:
                    raise
                anchor += db_bytes(blocks[anchor_end])
                anchor_end += 1
        if len(raw) % stride:
            raise ValueError(f"Unaligned source table {key}")
        tables[key] = {"first_source_label": first, "last_source_label": end - 1,
                       "source_line": blocks[first].line,
                       "dos_file_offset": at,
                       "original_pointer_u32": at + DOS_DATA_ADDRESS_DELTA,
                       "byte_count": len(raw), "stride_bytes": stride,
                       "count": len(raw) // stride, "sha256": sha(raw),
                       "hex": raw.hex(), "consumers": consumers,
                       "dos_matches_jjffe_data": True,
                       "location_anchor_byte_count": len(anchor),
                       "location_anchor_sha256": sha(anchor)}
        return raw

    drive_raw = table("drive_records", 7187, 7190, 16, ["F902", "F903", "F911"])
    masses_raw = table("installed_drive_masses", 7210, 7211, 4, ["F1533"])
    table("npc_drive_masses", 6261, 6262, 4, ["F774"])
    table("npc_hyperfuel", 6262, 6263, 4, ["F774"])
    table("npc_jetfuel", 6266, 6267, 4, ["F774"])
    if len(drive_raw) != 240 or len(masses_raw) != 60:
        raise ValueError("Unexpected drive table domain")
    masses = list(struct.unpack("<15I", masses_raw))

    # DATA5289 is split across four source labels; it is 66 packed 22B
    # equipment records. Four DOS tech/availability bytes differ in JJFFE.
    equipment_jjffe = b"".join(db_bytes(blocks[label]) for label in range(5289, 5293))
    if len(equipment_jjffe) != 66 * 22:
        raise ValueError("Unexpected equipment table size")
    equipment_at = unique_offset(executable, equipment_jjffe[22:220], "equipment anchor") - 22
    equipment_dos = executable[equipment_at:equipment_at + len(equipment_jjffe)]
    differences = [(i, old, new) for i, (old, new) in enumerate(zip(equipment_dos, equipment_jjffe))
                   if old != new]
    if differences != EQUIPMENT_DIFFERENCES:
        raise ValueError("Unknown DOS/JJFFE equipment variant")
    tables["equipment_records"] = {
        "first_source_label": 5289, "last_source_label": 5292,
        "source_line": blocks[5289].line, "dos_file_offset": equipment_at,
        "original_pointer_u32": equipment_at + DOS_DATA_ADDRESS_DELTA,
        "byte_count": len(equipment_dos), "stride_bytes": 22, "count": 66,
        "hex": equipment_dos.hex(), "sha256": sha(equipment_dos),
        "jjffe_sha256": sha(equipment_jjffe), "dos_matches_jjffe_data": False,
        "consumers": ["F390", "F391", "F408", "F410"],
        "variant_differences": [
            {"byte_offset": i, "equipment_index": i // 22, "record_byte": i % 22,
             "dos_byte": old, "jjffe_byte": new} for i, old, new in differences],
    }
    equipment_by_drive = {}
    for index in range(66):
        raw = equipment_dos[index * 22:(index + 1) * 22]
        if raw[16] != 3:
            continue
        buy, sell, mass, flags = struct.unpack("<4I", raw[:16])
        drive_index = raw[18]
        if mass != masses[drive_index] or drive_index in equipment_by_drive:
            raise ValueError("Drive installation mass/index mismatch")
        equipment_by_drive[drive_index] = {
            "equipment_index": index, "dos_file_offset": equipment_at + index * 22,
            "hex": raw.hex(), "mass_tonnes_u32": mass,
            "purchase_price_raw_u32": buy, "sale_price_raw_u32": sell,
            "flags_u32": flags, "type_u8": raw[16], "drive_index_u8": drive_index,
            "availability_bytes_hex": raw[19:22].hex(),
        }

    drives = []
    for index in range(15):
        raw = drive_raw[index * 16:(index + 1) * 16]
        coefficient, correction, threshold, name = struct.unpack("<4I", raw)
        drives.append({
            "index": index, "hex": raw.hex(),
            "dos_file_offset": tables["drive_records"]["dos_file_offset"] + index * 16,
            "coefficient_u32": coefficient, "correction_u32": correction,
            "capacity_threshold_tonnes_u32": threshold, "name_ff_code": name,
            "mass_tonnes_u32": masses[index],
            "fuel_commodity_index": 20 if index >= 10 else 19,
            "fuel_policy": "F903 drive>=10 military; otherwise hydrogen, including zero-range entries",
            "equipment": equipment_by_drive.get(index),
        })

    specs = {}
    for entry in registry["ships"]:
        index = int(entry["index"])
        at, descriptor_at = int(entry["spec_offset"], 16), int(entry["descriptor_offset"], 16)
        raw = executable[at:at + 24]
        pointer = struct.unpack_from("<I", executable, descriptor_at + 0x38)[0]
        if raw.hex() != entry["spec_hex"] or sha(raw) != entry["spec_sha256"]:
            raise ValueError(f"Registry specification mismatch for model {index}")
        if pointer != at + DOS_DATA_ADDRESS_DELTA:
            raise ValueError(f"F1538 descriptor+38 pointer mismatch for model {index}")
        mass, capacity = struct.unpack_from("<hh", raw, 6)
        stock = struct.unpack_from("<H", raw, 20)[0]
        specs[str(index)] = {
            "model_index": index, "name_en": entry["name_en"],
            "descriptor_file_offset": descriptor_at, "spec_file_offset": at,
            "original_spec_pointer_u32": pointer, "spec_hex": raw.hex(), "spec_sha256": sha(raw),
            "hull_mass_tonnes_s16": mass, "internal_capacity_tonnes_s16": capacity,
            "stock_drive_word_u16": stock,
            "builtin_drive": bool(stock & 0x8000),
            "builtin_drive_index": (stock & 255) if stock & 0x8000 else None,
            "stock_drive_low_u8": stock & 255, "stock_drive_high_u8": stock >> 8,
            "stock_word_policy": "F1533 installs low byte only when signed word<0; positive word is not an equipped-state proof",
        }
    if sorted(map(int, specs)) != list(range(15, 72)):
        raise ValueError("Expected 57 original model specifications, indices15..71")

    profiles = {
        "cobra": {"source_model_index": 38, "source_drive_index": 3,
                  "hydrogen": 4, "military": 0, "waste": 0,
                  "fixed_equipment_space_t": 6, "original_starter": True,
                  "source_start_selector": 3, "source_equipment_capacity_decrement_t": 31,
                  "source_equipment_bits_u32": 0x00040000,
                  "source_forward_weapon_u8": 0x88, "source_missile_bytes_hex": "82828282",
                  "source_jetfuel_raw_u32": 0x40000000,
                  "policy": "F998 selector3 loadout subset only; scenario position, money, mission and auxiliary craft are not imported"},
        "eagle": {"source_model_index": 24, "source_drive_index": 2,
                  "hydrogen": 1, "military": 0, "waste": 0,
                  "fixed_equipment_space_t": 6, "original_starter": False,
                  "fitting_reference_model_index": 23, "fitting_reference_start_selector": 1,
                  "source_equipment_capacity_decrement_t": 16,
                  "source_equipment_bits_u32": 0x40240000,
                  "source_forward_weapon_u8": 0x88, "source_missile_bytes_hex": "8282",
                  "source_jetfuel_raw_u32": 0x20000000,
                  "policy": "Explicit new-session MkII fitting adapter: model24 spec/name, model23 F998 selector1 drive/fuel/aggregate equipment space. This is not an original model24 starting profile; old registry alias23 is unchanged"},
        "shuttle": {"source_model_index": 15, "source_drive_index": 1,
                    "hydrogen": 0, "military": 0, "waste": 0,
                    "fixed_equipment_space_t": 0, "original_starter": False,
                    "source_start_selector": None,
                    "source_jetfuel_raw_u32": None,
                    "policy": "Explicit bare stock adapter: F1533 model15 signed stock word0x8001 installs interplanetary drive1, mass4t consumes all4t internal capacity. No F998 Shuttle starting inventory or jetfuel is asserted"},
    }
    return {
        "schema": 1, "profile": PROFILE, "source_sha256": EXE_SHA,
        "source": {"executable": "FIRSTENC.EXE", "byte_count": len(executable),
                   "sha256": EXE_SHA, "jjffe_commit": COMMIT,
                   "ffe_asm_sha256": ASM_SHA, "ffedat_asm_sha256": DATA_SHA,
                   "dos_data_address_delta": DOS_DATA_ADDRESS_DELTA,
                   "address_policy": "file offsets are DOS offsets; source Pos comments are not DOS addresses"},
        "drive_table_hex": drive_raw.hex(), "drive_stride_bytes": 16, "drive_count": 15,
        "valid_drive_indices": list(range(15)), "drives": drives, "ship_specs": specs,
        "tables": tables, "new_session_profiles": profiles,
        "dos_instruction_anchors": code_anchors,
        "source_references": {
            "F390": "ffe.asm:28868 equipment record stride22, massDWORD+8 subtracted from D8889",
            "F408_F410": "ffe.asm:29507 drive byte at equipment+18; builtin spec word+20 forbids removal",
            "F833": "ffe.asm:56722 exact integer distance; F3007 formats hundredths ly",
            "F902": "ffe.asm:67122 standard drive indices2..9; signed spec mass+6 and capacity+8",
            "F903": "ffe.asm:67190 exact mass/range/fuel/duration and military waste branches",
            "F992": "ffe.asm:73562 resets38 cargo words and D8891; D8889 from body+116",
            "F998": "ffe.asm:74028 selectors1/2 use model23, selector3 model38, default model31; no model24/model15 start",
            "F1533": "ffe.asm:91083 builtin signedword+20 branch installs low drive byte and subtracts DATA7210 mass",
            "F1538": "ffe.asm:91412 descriptor table DATA4681, specification pointer descriptor+0x38",
        },
        "contracts": {
            "distance_units": "F833/F3007 integer hundredths of a light year; original truncation, not continuous Euclidean replacement",
            "mass": "F903 uses signed spec word+6 only, no cargo/equipment addition and no zero fallback; F902 substitutes1 for zero mass",
            "drive_field8": "F902 capacity threshold/F911 salvage quantity; do not use as installation mass",
            "installation_mass": "DATA7210 equals actual DATA5289 engine-record DWORD+8; F390 subtracts equipment mass from DATA8889",
            "cargo": "D8896 is38 cargoWORDs; D8901 hydrogen commodity19, D8902 military20, D8903 radioactive waste29; all are separate from PhysObj+11E jetfuel",
            "military_waste": "F903 mode2 drive>=10 consumes D8902 and adds same amount to D8903; normal hydrogen mode decreases occupied cargo D8891",
            "equipment": "F998 aggregate capacity decrement excludes cargo counted independently in D8891; fixed_equipment_space_t is decrement minus installed drive mass, not a reconstructed full inventory",
            "compatibility": "Profiles are opt-in NEW session adapters; no old-save or registry-alias migration",
            "scope": "57 raw specifications support quote lookup; they do not make57 playable ships or reproduce the full outfitting economy",
        },
        "source_variants": {
            "drive_table": "DOS bytes equal pinned JJFFE DATA7187..7189",
            "equipment_table": "DOS authoritative; four availability bytes differ from pinned JJFFE source, explicitly listed",
            "starting_routine": "F998 semantic immediate writes are DOS-checked separately; DOS stack frame differs from JJFFE, no whole-function byte-equality claim",
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exe", type=Path, default=Path("/workspace/ffe-original/FIRSTENC.EXE"))
    parser.add_argument("--source", type=Path, default=Path("/workspace/ffe-upstream/jjffe"))
    parser.add_argument("--registry", type=Path, default=PROJECT / "data/ffe_ship_registry.json")
    parser.add_argument("--output", type=Path, default=PROJECT / "data/ffe_hyperdrive.json")
    args = parser.parse_args()
    result = extract(args.exe.read_bytes(), (args.source / "ffe.asm").read_bytes(),
                     (args.source / "ffedat.asm").read_bytes(), json.loads(args.registry.read_text()))
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"path": str(args.output), "sha256": sha(args.output.read_bytes()),
                      "drive_count": result["drive_count"], "ship_spec_count": len(result["ship_specs"])}))


if __name__ == "__main__":
    main()
