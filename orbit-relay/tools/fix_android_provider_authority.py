#!/usr/bin/env python3
"""Repair Godot 4.6's non-Gradle provider authority collision, offline.

Usage: python3 tools/fix_android_provider_authority.py exported.apk unsigned.apk
The output MUST subsequently be zipaligned and signed. No key is read here.
Only AndroidX Startup's authority changes; FileProvider and its path resource
are preserved. Unexpected provider layouts fail closed for manual review.
"""

from __future__ import annotations

import argparse
from copy import copy
from hashlib import sha256
import json
import os
from pathlib import Path
import re
import struct
import tempfile
import zipfile

ANDROID = "http://schemas.android.com/apk/res/android"
FILE_PROVIDER = "androidx.core.content.FileProvider"
STARTUP_PROVIDER = "androidx.startup.InitializationProvider"
PATHS_RESOURCE = "res/xml/godot_provider_paths.xml"
NO_INDEX = 0xFFFFFFFF
TYPE_STRING = 3
MAX_MANIFEST = 4 * 1024 * 1024
ANDROID_ATTRIBUTE_IDS = {
    "name": 0x01010003, "exported": 0x01010010, "authorities": 0x01010018,
    "grantUriPermissions": 0x0101001B, "resource": 0x01010025,
}


class RepairError(ValueError):
    """Input is outside the narrowly supported export layout."""


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise RepairError(message)


def _u16(data: bytes, at: int) -> int:
    _require(0 <= at <= len(data) - 2, "Truncated Android XML word")
    return struct.unpack_from("<H", data, at)[0]


def _u32(data: bytes, at: int) -> int:
    _require(0 <= at <= len(data) - 4, "Truncated Android XML dword")
    return struct.unpack_from("<I", data, at)[0]


def _length8(data: bytes, at: int, end: int) -> tuple[int, int]:
    _require(at < end, "Truncated UTF-8 pool length")
    first = data[at]
    if first & 0x80:
        _require(at + 1 < end, "Truncated long UTF-8 pool length")
        return ((first & 0x7F) << 8) | data[at + 1], at + 2
    return first, at + 1


def _length16(data: bytes, at: int, end: int) -> tuple[int, int]:
    _require(at + 2 <= end, "Truncated UTF-16 pool length")
    first = _u16(data, at)
    if first & 0x8000:
        _require(at + 4 <= end, "Truncated long UTF-16 pool length")
        return ((first & 0x7FFF) << 16) | _u16(data, at + 2), at + 4
    return first, at + 2


def _pool(data: bytes, at: int, size: int, header: int) -> dict:
    _require(header == 28 and size >= 28, "Unsupported Android string-pool header")
    count, styles, flags, start, style_start = struct.unpack_from("<5I", data, at + 8)
    _require(0 < count <= 65536, "Invalid Android XML string count")
    _require(styles == 0 and style_start == 0, "Styled manifest strings require manual review")
    _require(flags & ~0x101 == 0, "Unsupported Android XML string flags")
    _require(28 + count * 4 <= start <= size, "Invalid Android XML string offsets")
    offsets = list(struct.unpack_from("<%dI" % count, data, at + 28))
    strings = []
    end = at + size
    for offset in offsets:
        cursor = at + start + offset
        _require(at + start <= cursor < end, "Android XML string offset outside pool")
        if flags & 0x100:
            units, cursor = _length8(data, cursor, end)
            length, cursor = _length8(data, cursor, end)
            _require(cursor + length < end and data[cursor + length] == 0, "Truncated UTF-8 pool string")
            value = data[cursor:cursor + length].decode("utf-8", errors="strict")
            _require(len(value.encode("utf-16-le")) // 2 == units, "UTF-8 pool character length mismatch")
        else:
            units, cursor = _length16(data, cursor, end)
            length = units * 2
            _require(cursor + length + 2 <= end and data[cursor + length:cursor + length + 2] == b"\0\0", "Truncated UTF-16 pool string")
            value = data[cursor:cursor + length].decode("utf-16-le", errors="strict")
        _require("\0" not in value, "Embedded NUL in Android XML string")
        strings.append(value)
    return {"at": at, "size": size, "count": count, "flags": flags, "start": start,
            "offsets": offsets, "strings": strings}


def _parse(data: bytes) -> dict:
    _require(8 <= len(data) <= MAX_MANIFEST, "Invalid binary Android XML size")
    _require(_u16(data, 0) == 3 and _u16(data, 2) == 8 and _u32(data, 4) == len(data), "Expected complete binary Android XML")
    chunks = []
    at = 8
    pool = None
    while at < len(data):
        _require(at + 8 <= len(data), "Truncated Android XML chunk")
        kind, header, size = struct.unpack_from("<HHI", data, at)
        _require(8 <= header <= size and size % 4 == 0 and at + size <= len(data), "Invalid Android XML chunk bounds")
        _require(kind in (1, 0x180, 0x100, 0x101, 0x102, 0x103), "Unsupported Android XML chunk")
        if kind == 1:
            _require(pool is None and not chunks, "Expected one leading Android XML string pool")
            pool = _pool(data, at, size, header)
        chunks.append((kind, at, header, size))
        at += size
    _require(at == len(data) and pool is not None, "Missing complete Android XML string pool")
    strings = pool["strings"]

    def text(index: int, optional: bool = False) -> str | None:
        if optional and index == NO_INDEX:
            return None
        _require(index < len(strings), "Android XML string reference outside pool")
        return strings[index]

    stack = []
    nodes = []
    roots = 0
    resource_map = []
    resource_map_seen = False
    xml_nodes_seen = False
    for kind, offset, header, size in chunks:
        if kind == 1:
            continue
        if kind == 0x180:
            _require(not resource_map_seen and not xml_nodes_seen and header == 8 and (size - 8) % 4 == 0, "Invalid or duplicate Android XML resource map")
            count = (size - 8) // 4
            _require(count <= len(strings), "Android XML resource map exceeds string pool")
            resource_map = list(struct.unpack_from("<%dI" % count, data, offset + 8)) if count else []
            resource_map_seen = True
            continue
        xml_nodes_seen = True
        _require(header == 16, "Unsupported Android XML node header")
        if kind in (0x100, 0x101):
            _require(size == 24, "Invalid Android XML namespace node")
            text(_u32(data, offset + 16), True)
            text(_u32(data, offset + 20))
            continue
        namespace, name = text(_u32(data, offset + 16), True), text(_u32(data, offset + 20))
        if kind == 0x103:
            _require(size == 24 and stack and (namespace, name) == (stack[-1]["namespace"], stack[-1]["name"]), "Unbalanced Android XML element")
            stack.pop()
            continue
        _require(size >= 36, "Truncated Android XML start element")
        attribute_start, attribute_size, attribute_count, id_index, class_index, style_index = struct.unpack_from("<6H", data, offset + 24)
        _require(attribute_start == 20 and attribute_size == 20 and size == 36 + 20 * attribute_count, "Unsupported Android XML attribute layout")
        _require(max(id_index, class_index, style_index) <= attribute_count, "Invalid Android XML special attribute")
        node = {"name": name, "namespace": namespace, "parent": stack[-1] if stack else None, "attrs": {}, "children": []}
        if stack:
            stack[-1]["children"].append(node)
        else:
            roots += 1
        for index in range(attribute_count):
            attr = offset + 36 + index * 20
            ns, key, raw = struct.unpack_from("<3I", data, attr)
            name_index = key
            value_size, reserved, value_type, value = struct.unpack_from("<HBBI", data, attr + 12)
            _require(value_size == 8 and reserved == 0, "Invalid Android XML typed attribute")
            ns, key, raw_text = text(ns, True), text(key), text(raw, True)
            if ns == ANDROID and key in ANDROID_ATTRIBUTE_IDS:
                _require(name_index < len(resource_map) and resource_map[name_index] == ANDROID_ATTRIBUTE_IDS[key], "Android attribute resource-ID mismatch: " + key)
            typed = text(value) if value_type == TYPE_STRING else value
            if value_type == TYPE_STRING and raw_text is not None:
                _require(raw_text == typed, "Conflicting raw/typed Android XML attribute")
            _require((ns, key) not in node["attrs"], "Duplicate Android XML attribute")
            node["attrs"][(ns, key)] = {"at": attr, "raw": raw, "raw_text": raw_text, "type": value_type, "value": typed}
        nodes.append(node)
        stack.append(node)
    _require(not stack and roots == 1, "Android XML must have one complete root")
    return {"pool": pool, "nodes": nodes}


def _attribute(node: dict, name: str, namespace: str | None = ANDROID, kind: int | None = None) -> dict:
    value = node["attrs"].get((namespace, name))
    _require(value is not None and (kind is None or value["type"] == kind), "Missing or invalid %s attribute on %s" % (name, node["name"]))
    return value


def _providers(parsed: dict) -> tuple[str, dict, dict]:
    nodes = parsed["nodes"]
    manifest = nodes[0]
    _require(manifest["name"] == "manifest" and manifest["namespace"] is None, "Expected Android manifest root")
    package = _attribute(manifest, "package", None, TYPE_STRING)["value"]
    _require(re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)+", package) is not None, "Unexpected Android package name")
    applications = [node for node in nodes if node["name"] == "application"]
    _require(len(applications) == 1 and applications[0]["namespace"] is None and applications[0]["parent"] is manifest, "Expected one direct manifest application")
    application = applications[0]
    found = {}
    for node in nodes:
        if node["name"] != "provider":
            continue
        _require(node["namespace"] is None and node["parent"] is application, "Unexpected Android provider placement")
        name = _attribute(node, "name", kind=TYPE_STRING)["value"]
        _require(name in (FILE_PROVIDER, STARTUP_PROVIDER) and name not in found, "Unknown or duplicate Android provider class")
        _require(_attribute(node, "exported", kind=0x12)["value"] == 0, "Expected unexported Android providers")
        found[name] = node
    _require(set(found) == {FILE_PROVIDER, STARTUP_PROVIDER}, "Expected exactly FileProvider and AndroidX Startup")
    file_provider, startup = found[FILE_PROVIDER], found[STARTUP_PROVIDER]
    _require(_attribute(file_provider, "grantUriPermissions", kind=0x12)["value"] != 0, "FileProvider URI grants are disabled")
    paths = [node for node in file_provider["children"] if node["name"] == "meta-data" and _attribute(node, "name", kind=TYPE_STRING)["value"] == "android.support.FILE_PROVIDER_PATHS"]
    _require(len(paths) == 1 and _attribute(paths[0], "resource", kind=1)["value"] != 0, "Missing FileProvider path resource")
    file_authority = _attribute(file_provider, "authorities", kind=TYPE_STRING)["value"]
    startup_authority = _attribute(startup, "authorities", kind=TYPE_STRING)["value"]
    _require(file_authority == package + ".fileprovider", "Unexpected FileProvider authority")
    _require(startup_authority in (file_authority, package + ".androidx-startup"), "Unexpected AndroidX Startup authority")
    return package, file_provider, startup


def _encode_length8(length: int) -> bytes:
    _require(length < 0x8000, "String exceeds UTF-8 Android pool limit")
    return bytes((length,)) if length < 0x80 else bytes((0x80 | (length >> 8), length & 0xFF))


def _append_string(data: bytes, pool: dict, value: str) -> tuple[bytes, int]:
    old = data[pool["at"]:pool["at"] + pool["size"]]
    if pool["flags"] & 0x100:
        encoded = value.encode("utf-8")
        encoded = _encode_length8(len(value.encode("utf-16-le")) // 2) + _encode_length8(len(encoded)) + encoded + b"\0"
    else:
        encoded = value.encode("utf-16-le")
        length = len(encoded) // 2
        prefix = struct.pack("<H", length) if length < 0x8000 else struct.pack("<HH", 0x8000 | (length >> 16), length & 0xFFFF)
        encoded = prefix + encoded + b"\0\0"
    table_end = 28 + pool["count"] * 4
    old_data = old[pool["start"]:]
    new = bytearray(old[:table_end] + struct.pack("<I", len(old_data)) + old[table_end:pool["start"]] + old_data + encoded)
    new.extend(b"\0" * (-len(new) % 4))
    struct.pack_into("<I", new, 4, len(new))
    struct.pack_into("<I", new, 8, pool["count"] + 1)
    struct.pack_into("<I", new, 16, pool["flags"] & ~1)  # Appended pool is not sorted.
    struct.pack_into("<I", new, 20, pool["start"] + 4)
    return bytes(new), pool["count"]


def fix_manifest(manifest_bytes: bytes) -> tuple[bytes, dict]:
    """Return corrected binary XML and a semantic authority audit."""
    parsed = _parse(manifest_bytes)
    package, file_provider, startup = _providers(parsed)
    authority = _attribute(startup, "authorities", kind=TYPE_STRING)
    wanted = package + ".androidx-startup"
    changed = authority["value"] != wanted
    output = manifest_bytes
    if changed:
        pool = parsed["pool"]
        new_pool, new_index = _append_string(manifest_bytes, pool, wanted)
        patched = bytearray(manifest_bytes)
        if authority["raw"] != NO_INDEX:
            struct.pack_into("<I", patched, authority["at"] + 8, new_index)
        struct.pack_into("<I", patched, authority["at"] + 16, new_index)
        output = bytearray(patched[:pool["at"]] + new_pool + patched[pool["at"] + pool["size"]:])
        struct.pack_into("<I", output, 4, len(output))
        output = bytes(output)
    after = _parse(output)
    package_after, file_after, startup_after = _providers(after)
    _require(package_after == package and _attribute(file_after, "authorities")["value"] == _attribute(file_provider, "authorities")["value"], "FileProvider identity changed")
    _require(_attribute(startup_after, "authorities")["value"] == wanted, "Startup authority patch failed")
    _require(_semantics(parsed, startup, wanted) == _semantics(after), "Repair changed unrelated Android manifest semantics")
    return output, {"changed": changed, "package": package,
                    "file_provider_authority": package + ".fileprovider", "startup_authority": wanted,
                    "provider_authorities_unique": True,
                    "manifest_before_sha256": sha256(manifest_bytes).hexdigest(),
                    "manifest_after_sha256": sha256(output).hexdigest()}


def _semantics(parsed: dict, modified: dict | None = None, authority: str = "") -> list:
    """Independently compare every element/attribute after the pool rewrite."""
    indices = {id(node): index for index, node in enumerate(parsed["nodes"])}
    result = []
    for node in parsed["nodes"]:
        attrs = []
        for (namespace, name), attr in node["attrs"].items():
            value, raw = attr["value"], attr["raw_text"]
            if node is modified and namespace == ANDROID and name == "authorities":
                value = authority
                raw = authority if raw is not None else None
            attrs.append((namespace, name, attr["type"], value, raw))
        result.append((node["namespace"], node["name"], indices.get(id(node["parent"])), attrs))
    return result


def _signature(name: str) -> bool:
    upper = name.upper()
    if not upper.startswith("META-INF/"):
        return False
    leaf = upper.removeprefix("META-INF/")
    return "/" not in leaf and (leaf == "MANIFEST.MF" or leaf.startswith("SIG-") or leaf.endswith((".SF", ".RSA", ".DSA", ".EC")))


def _safe_name(name: str) -> bool:
    raw = name[:-1] if name.endswith("/") else name
    return bool(raw) and "\\" not in name and "\0" not in name and ":" not in name and all(part not in ("", ".", "..") for part in raw.split("/"))


def fix_apk(input_path: str | Path, output_path: str | Path) -> dict:
    """Write an unsigned APK atomically, preserving every nonsignature entry."""
    source, destination = Path(input_path), Path(output_path)
    _require(source.resolve() != destination.resolve(), "Input and output APK paths must differ")
    _require(not destination.exists(), "Output APK already exists")
    temporary = None
    try:
        with zipfile.ZipFile(source) as original:
            records = original.infolist()
            names = [entry.filename for entry in records]
            _require(len(names) == len(set(names)), "Duplicate APK ZIP entry")
            _require(all(_safe_name(name) for name in names), "Unsafe APK ZIP entry path")
            _require(all(entry.compress_type in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED) and not entry.flag_bits & 1 for entry in records), "Unsupported/encrypted APK ZIP entry")
            _require({"AndroidManifest.xml", "resources.arsc", PATHS_RESOURCE}.issubset(names), "Missing required Android/FileProvider resource")
            _require(original.testzip() is None, "Corrupt APK ZIP content")
            manifest, audit = fix_manifest(original.read("AndroidManifest.xml"))
            destination.parent.mkdir(parents=True, exist_ok=True)
            descriptor, temporary = tempfile.mkstemp(prefix=".provider-authority-", suffix=".apk", dir=destination.parent)
            os.close(descriptor)
            removed = []
            expected = {}
            with zipfile.ZipFile(temporary, "w", allowZip64=True) as corrected:
                corrected.comment = original.comment
                for entry in records:
                    if _signature(entry.filename):
                        removed.append(entry.filename)
                        continue
                    content = manifest if entry.filename == "AndroidManifest.xml" else original.read(entry)
                    corrected.writestr(copy(entry), content)
                    expected[entry.filename] = sha256(content).hexdigest()
            with zipfile.ZipFile(temporary) as corrected:
                _require(corrected.testzip() is None and set(corrected.namelist()) == set(expected), "Corrected APK ZIP integrity mismatch")
                _require(all(sha256(corrected.read(name)).hexdigest() == digest for name, digest in expected.items()), "Corrected APK entry mismatch")
                _, final = fix_manifest(corrected.read("AndroidManifest.xml"))
                _require(not final["changed"], "Corrected authority manifest is not idempotent")
            # Link refuses a racing/preexisting output instead of overwriting it.
            os.link(temporary, destination)
            os.unlink(temporary)
            temporary = None
            return {**audit, "input": str(source), "output": str(destination), "entries_preserved": len(expected),
                    "old_v1_signature_entries_removed": removed, "unsigned_output": True,
                    "zipalign_and_apksigner_required": True, "file_provider_paths_sha256": expected[PATHS_RESOURCE],
                    "input_sha256": sha256(source.read_bytes()).hexdigest(),
                    "output_sha256": sha256(destination.read_bytes()).hexdigest()}
    finally:
        if temporary is not None:
            Path(temporary).unlink(missing_ok=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path, help="Fresh unsigned APK; zipalign and sign it afterwards")
    args = parser.parse_args(argv)
    try:
        report = fix_apk(args.input, args.output)
    except (RepairError, OSError, UnicodeError, zipfile.BadZipFile, struct.error) as error:
        parser.exit(1, "Android provider repair rejected: %s\n" % error)
    print(json.dumps(report, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
