#!/usr/bin/env python3
"""Independent binary-XML/container tests; no Android device or network needed."""
from __future__ import annotations

import importlib.util
import struct
import subprocess
import sys
import tempfile
import unittest
import warnings
import zipfile
from pathlib import Path

TOOL = Path(__file__).with_name("fix_android_provider_authority.py")
PACKAGE = "org.orbitrelay.game"
FILE_PROVIDER = "androidx.core.content.FileProvider"
STARTUP_PROVIDER = "androidx.startup.InitializationProvider"
ANDROID_URI = "http://schemas.android.com/apk/res/android"
NONE = 0xFFFFFFFF


def _chunk(kind: int, payload: bytes, header_size: int = 8) -> bytes:
    return struct.pack("<HHI", kind, header_size, 8 + len(payload)) + payload


def _length8(length: int) -> bytes:
    return bytes([length]) if length < 128 else bytes([(length >> 8) | 128, length & 255])


def _length16(length: int) -> bytes:
    return struct.pack("<H", length) if length < 32768 else struct.pack("<HH", (length >> 16) | 32768, length & 65535)


def _string_pool(strings: list[str], utf8: bool) -> bytes:
    offsets = []
    data = bytearray()
    for value in strings:
        offsets.append(len(data))
        utf16_units = len(value.encode("utf-16-le")) // 2
        if utf8:
            encoded = value.encode("utf-8")
            data.extend(_length8(utf16_units) + _length8(len(encoded)) + encoded + b"\0")
        else:
            data.extend(_length16(utf16_units) + value.encode("utf-16-le") + b"\0\0")
    data.extend(b"\0" * (-len(data) % 4))
    start = 28 + len(offsets) * 4
    header = struct.pack("<HHIIIIII", 1, 28, start + len(data), len(strings), 0, 0x100 if utf8 else 0, start, 0)
    return header + b"".join(struct.pack("<I", offset) for offset in offsets) + data


def manifest_fixture(*, utf8: bool = True, distinct: bool = False,
                     shared_authority: bool = True, typed_only: bool = False,
                     extra_provider: str | None = None, omit_startup: bool = False,
                     duplicate_startup: bool = False, wrong_file_authority: bool = False,
                     nested_application: bool = False, duplicate_application: bool = False,
                     namespaced_application: bool = False) -> bytes:
    # Attribute names occupy the first slots, matching the resource-map layout.
    strings = ["name", "exported", "authorities", "grantUriPermissions", "resource", "value",
               "manifest", "package", "application", "provider", "meta-data", "android", ANDROID_URI,
               PACKAGE, FILE_PROVIDER, STARTUP_PROVIDER, PACKAGE + ".fileprovider",
               "android.support.FILE_PROVIDER_PATHS", "androidx.profileinstaller.ProfileInstallerInitializer",
               "androidx.startup", "Кириллица 🌍 " + "x" * 260]

    def index(value: str, *, unique: bool = False) -> int:
        if not unique and value in strings:
            return strings.index(value)
        strings.append(value)
        return len(strings) - 1

    def string_attr(name: str, value: str, *, android: bool = True, raw: bool = True,
                    unique: bool = False) -> bytes:
        value_index = index(value, unique=unique)
        return struct.pack("<IIIHBBI", index(ANDROID_URI) if android else NONE, index(name),
                           value_index if raw else NONE, 8, 0, 3, value_index)

    def boolean_attr(name: str, value: bool) -> bytes:
        return struct.pack("<IIIHBBI", index(ANDROID_URI), index(name), NONE, 8, 0, 0x12,
                           0xFFFFFFFF if value else 0)

    def node(kind: int, payload: bytes) -> bytes:
        return struct.pack("<HHIII", kind, 16, 16 + len(payload), 1, NONE) + payload

    def start(name: str, attributes: list[bytes], namespace: str | None = None) -> bytes:
        return node(0x102, struct.pack("<IIHHHHHH", index(namespace) if namespace else NONE, index(name), 20, 20,
                                       len(attributes), 0, 0, 0) + b"".join(attributes))

    def end(name: str, namespace: str | None = None) -> bytes:
        return node(0x103, struct.pack("<II", index(namespace) if namespace else NONE, index(name)))

    def provider(class_name: str, authority: str, *, file: bool = False) -> bytes:
        attributes = [string_attr("name", class_name), boolean_attr("exported", False),
                      string_attr("authorities", authority,
                                  raw=not (typed_only and class_name == STARTUP_PROVIDER),
                                  unique=not shared_authority and class_name == STARTUP_PROVIDER)]
        if file:
            attributes.append(boolean_attr("grantUriPermissions", True))
        result = start("provider", attributes)
        if file:
            resource = struct.pack("<IIIHBBI", index(ANDROID_URI), index("resource"), NONE, 8, 0, 1, 0x7F0E0000)
            result += start("meta-data", [string_attr("name", "android.support.FILE_PROVIDER_PATHS"), resource])
            result += end("meta-data")
        elif class_name == STARTUP_PROVIDER:
            result += start("meta-data", [string_attr("name", "androidx.profileinstaller.ProfileInstallerInitializer"),
                                          string_attr("value", "androidx.startup")]) + end("meta-data")
        return result + end("provider")

    nodes = node(0x100, struct.pack("<II", index("android"), index(ANDROID_URI)))
    nodes += start("manifest", [string_attr("package", PACKAGE, android=False)])
    if nested_application:
        nodes += start("unexpected-wrapper", [])
    app_namespace = ANDROID_URI if namespaced_application else None
    nodes += start("application", [], app_namespace)
    nodes += provider(FILE_PROVIDER, "foreign.package.fileprovider" if wrong_file_authority else PACKAGE + ".fileprovider", file=True)
    authority = PACKAGE + (".androidx-startup" if distinct else ".fileprovider")
    if not omit_startup:
        nodes += provider(STARTUP_PROVIDER, authority)
    if duplicate_startup:
        nodes += provider(STARTUP_PROVIDER, authority)
    if extra_provider is not None:
        nodes += provider(extra_provider, PACKAGE + ".third")
    nodes += end("application", app_namespace)
    if nested_application:
        nodes += end("unexpected-wrapper")
    if duplicate_application:
        nodes += start("application", []) + end("application")
    nodes += end("manifest")
    nodes += node(0x101, struct.pack("<II", index("android"), index(ANDROID_URI)))
    resources = _chunk(0x180, struct.pack("<IIIIII", 0x01010003, 0x01010010, 0x01010018,
                                         0x0101001B, 0x01010025, 0x01010024))
    contents = _string_pool(strings, utf8) + resources + nodes
    return _chunk(3, contents)


def inspect_manifest(data: bytes) -> tuple[list[str], str, list[dict[str, tuple[int, str | int, str | None]]]]:
    """Minimal independent fixture reader; does not call the utility parser."""
    if struct.unpack_from("<HHI", data) != (3, 8, len(data)):
        raise AssertionError("Invalid outer binary XML size")
    strings: list[str] = []
    providers = []
    package = ""
    offset = 8
    while offset < len(data):
        kind, header_size, size = struct.unpack_from("<HHI", data, offset)
        if size < header_size or offset + size > len(data):
            raise AssertionError("Invalid chunk bounds")
        if kind == 1:
            count, _, flags, start, _ = struct.unpack_from("<IIIII", data, offset + 8)
            for slot in range(count):
                pos = offset + start + struct.unpack_from("<I", data, offset + header_size + slot * 4)[0]
                if flags & 0x100:
                    def get_length(at: int) -> tuple[int, int]:
                        first = data[at]
                        return (((first & 127) << 8) | data[at + 1], at + 2) if first & 128 else (first, at + 1)
                    _, pos = get_length(pos)
                    length, pos = get_length(pos)
                    strings.append(data[pos:pos + length].decode("utf-8"))
                else:
                    length = struct.unpack_from("<H", data, pos)[0]
                    pos += 2
                    if length & 0x8000:
                        length = ((length & 0x7FFF) << 16) | struct.unpack_from("<H", data, pos)[0]
                        pos += 2
                    strings.append(data[pos:pos + length * 2].decode("utf-16-le"))
        elif kind == 0x102:
            name_index = struct.unpack_from("<I", data, offset + 20)[0]
            attr_start, attr_size, count = struct.unpack_from("<HHH", data, offset + 24)
            values = {}
            for slot in range(count):
                at = offset + 16 + attr_start + slot * attr_size
                _, name, raw, typed_size, _, value_type, value = struct.unpack_from("<IIIHBBI", data, at)
                if typed_size != 8:
                    raise AssertionError("Invalid typed value size")
                values[strings[name]] = (value_type, strings[value] if value_type == 3 else value,
                                         strings[raw] if raw != NONE else None)
            if strings[name_index] == "manifest":
                package = str(values["package"][1])
            elif strings[name_index] == "provider":
                providers.append(values)
        offset += size
    if offset != len(data):
        raise AssertionError("Trailing binary XML data")
    return strings, package, providers


class AuthorityFixTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        spec = importlib.util.spec_from_file_location("authority_fix_under_test", TOOL)
        assert spec and spec.loader
        cls.tool = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = cls.tool
        spec.loader.exec_module(cls.tool)

    def test_shared_and_distinct_pool_slots_utf8_and_utf16(self) -> None:
        for utf8 in (True, False):
            for shared in (True, False):
                with self.subTest(utf8=utf8, shared=shared):
                    original = manifest_fixture(utf8=utf8, shared_authority=shared)
                    old_strings, _, old = inspect_manifest(original)
                    fixed, report = self.tool.fix_manifest(original)
                    strings, package, providers = inspect_manifest(fixed)
                    self.assertIsInstance(report, dict)
                    self.assertEqual(package, PACKAGE)
                    self.assertEqual(len(providers), 2)
                    by_name = {entry["name"][1]: entry for entry in providers}
                    self.assertEqual(by_name[FILE_PROVIDER], old[0], "FileProvider attributes must stay untouched")
                    self.assertEqual(by_name[STARTUP_PROVIDER]["authorities"], (3, PACKAGE + ".androidx-startup", PACKAGE + ".androidx-startup"))
                    self.assertEqual(by_name[STARTUP_PROVIDER]["exported"], old[1]["exported"])
                    self.assertIn(old_strings[20], strings, "Long Unicode strings retain both length prefixes and content")
                    self.assertEqual(self.tool.fix_manifest(fixed)[0], fixed, "A repaired manifest must be byte-idempotent")

    def test_typed_only_attribute_keeps_no_raw_value(self) -> None:
        fixed, _ = self.tool.fix_manifest(manifest_fixture(typed_only=True))
        provider = inspect_manifest(fixed)[2][1]
        self.assertEqual(provider["authorities"], (3, PACKAGE + ".androidx-startup", None))

    def test_already_naturally_unique_manifest_is_unchanged(self) -> None:
        for utf8 in (True, False):
            original = manifest_fixture(utf8=utf8, distinct=True)
            self.assertEqual(self.tool.fix_manifest(original)[0], original)

    def test_ambiguous_unknown_or_incomplete_provider_layout_rejected(self) -> None:
        fixtures = [manifest_fixture(omit_startup=True), manifest_fixture(duplicate_startup=True),
                    manifest_fixture(extra_provider="example.UnknownProvider"),
                    manifest_fixture(wrong_file_authority=True), manifest_fixture(nested_application=True),
                    manifest_fixture(duplicate_application=True), manifest_fixture(namespaced_application=True)]
        for original in fixtures:
            with self.subTest(size=len(original)):
                with self.assertRaises(Exception):
                    self.tool.fix_manifest(original)

    def test_malformed_axml_rejected(self) -> None:
        original = manifest_fixture()
        wrong_size = bytearray(original)
        struct.pack_into("<I", wrong_size, 4, len(original) + 4)
        malformed_pool = bytearray(original)
        struct.pack_into("<I", malformed_pool, 8 + 12, 0x7FFFFFFF)
        for value in (b"", original[:20], original[:-1], bytes(wrong_size), bytes(malformed_pool)):
            with self.subTest(size=len(value)):
                with self.assertRaises(Exception):
                    self.tool.fix_manifest(value)

    def test_styled_pool_is_explicitly_unsupported(self) -> None:
        original = manifest_fixture()
        pool = original[8:8 + struct.unpack_from("<I", original, 12)[0]]
        count, _, flags, old_start, _ = struct.unpack_from("<IIIII", pool, 8)
        offsets = pool[28:old_start]
        strings = pool[old_start:]
        start = old_start + 4
        spans = struct.pack("<IIIIII", 20, 0, 2, NONE, NONE, NONE)
        styles_start = start + len(strings)
        styled = (struct.pack("<HHIIIIII", 1, 28, styles_start + len(spans), count, 1, flags, start, styles_start)
                  + offsets + struct.pack("<I", 0) + strings + spans)
        modified = _chunk(3, styled + original[8 + len(pool):])
        # Fixture remains structurally readable; rejection is a declared
        # unsupported-style policy, rather than merely truncation detection.
        self.assertEqual(inspect_manifest(modified)[1], PACKAGE)
        with self.assertRaises(Exception):
            self.tool.fix_manifest(modified)

    def test_unknown_xml_chunk_is_not_silently_rewritten(self) -> None:
        original = manifest_fixture()
        modified = _chunk(3, original[8:] + _chunk(0x7777, b"word"))
        with self.assertRaises(Exception):
            self.tool.fix_manifest(modified)

    def test_resource_map_identity_is_required_not_just_string_names(self) -> None:
        original = manifest_fixture()
        pool_size = struct.unpack_from("<I", original, 12)[0]
        resource_at = 8 + pool_size
        resource_size = struct.unpack_from("<I", original, resource_at + 4)[0]
        wrong_id = bytearray(original)
        struct.pack_into("<I", wrong_id, resource_at + 8 + 2 * 4, 0x01010010)
        wrong_header = bytearray(original)
        struct.pack_into("<H", wrong_header, resource_at + 2, 12)
        missing = _chunk(3, original[8:resource_at] + original[resource_at + resource_size:])
        duplicated = _chunk(3, original[8:resource_at] + original[resource_at:resource_at + resource_size]
                            + original[resource_at:])
        for value in (bytes(wrong_id), bytes(wrong_header), missing, duplicated):
            with self.subTest(size=len(value)):
                with self.assertRaises(Exception):
                    self.tool.fix_manifest(value)

    @staticmethod
    def write_apk(path: Path, manifest: bytes, *, duplicate: bool = False, unsafe: str | None = None) -> dict[str, bytes]:
        members = {"AndroidManifest.xml": manifest, "classes.dex": b"dex\n035\0" + bytes(range(64)),
                   "resources.arsc": b"resource table fixture", "res/xml/godot_provider_paths.xml": b"binary paths untouched",
                   "assets/report.zip": b"PK\x03\x04zip payload untouched", "lib/arm64-v8a/libgodot_android.so": bytes(range(200)),
                   "META-INF/androidx.core_core.version": b"1.15.0", "META-INF/services/example.Service": b"example.Implementation",
                   "META-INF/MANIFEST.MF": b"Signature manifest", "META-INF/CERT.SF": b"Signature file",
                   "META-INF/CERT.RSA": b"old signature", "META-INF/CERT.DSA": b"old signature", "META-INF/CERT.EC": b"old signature"}
        with zipfile.ZipFile(path, "w") as archive:
            archive.comment = b"APK container comment"
            for number, (name, value) in enumerate(members.items()):
                info = zipfile.ZipInfo(name, (2024, 2, 3, 4, 5, 6))
                info.compress_type = zipfile.ZIP_STORED if name.startswith("lib/") else zipfile.ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                info.comment = b"entry comment"
                info.extra = struct.pack("<HH", 0xCAFE, 3) + b"abc"
                archive.writestr(info, value)
            if unsafe:
                archive.writestr(unsafe, b"unsafe")
            if duplicate:
                with warnings.catch_warnings():
                    warnings.simplefilter("ignore", UserWarning)
                    archive.writestr("AndroidManifest.xml", manifest)
        return members

    def test_apk_preserves_payload_and_non_signature_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            source, output = Path(folder) / "source.apk", Path(folder) / "unsigned.apk"
            members = self.write_apk(source, manifest_fixture(shared_authority=True))
            report = self.tool.fix_apk(source, output)
            self.assertIsInstance(report, dict)
            with zipfile.ZipFile(source) as before, zipfile.ZipFile(output) as after:
                self.assertIsNone(after.testzip())
                self.assertEqual(after.comment, before.comment)
                expected = {name for name in members if name not in {"META-INF/MANIFEST.MF", "META-INF/CERT.SF", "META-INF/CERT.RSA", "META-INF/CERT.DSA", "META-INF/CERT.EC"}}
                self.assertEqual(set(after.namelist()), expected)
                for name in expected - {"AndroidManifest.xml"}:
                    self.assertEqual(after.read(name), members[name], name)
                    a, b = before.getinfo(name), after.getinfo(name)
                    self.assertEqual((a.date_time, a.compress_type, a.external_attr, a.extra, a.comment),
                                     (b.date_time, b.compress_type, b.external_attr, b.extra, b.comment), name)
                authorities = [entry["authorities"][1] for entry in inspect_manifest(after.read("AndroidManifest.xml"))[2]]
                self.assertEqual(authorities, [PACKAGE + ".fileprovider", PACKAGE + ".androidx-startup"])

    def test_unsafe_duplicate_or_invalid_input_creates_no_output(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            source, output = Path(folder) / "source.apk", Path(folder) / "unsigned.apk"
            for kwargs in ({"duplicate": True}, {"unsafe": "../outside"}, {"unsafe": "/absolute"},
                           {"unsafe": "assets\\escape"}, {"unsafe": "assets/./escape"},
                           {"unsafe": "assets//escape"}, {"unsafe": "C:escape"}):
                output.unlink(missing_ok=True)
                self.write_apk(source, manifest_fixture(), **kwargs)
                with self.subTest(kwargs=kwargs):
                    with self.assertRaises(Exception):
                        self.tool.fix_apk(source, output)
                    self.assertFalse(output.exists())
            output.unlink(missing_ok=True)
            self.write_apk(source, manifest_fixture(omit_startup=True))
            completed = subprocess.run([sys.executable, str(TOOL), str(source), str(output)], capture_output=True, text=True)
            self.assertNotEqual(completed.returncode, 0)
            self.assertFalse(output.exists(), "Failed CLI validation cannot leave a plausible APK")

    def test_input_and_preexisting_outputs_are_never_overwritten(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            source, output = Path(folder) / "source.apk", Path(folder) / "unsigned.apk"
            self.write_apk(source, manifest_fixture())
            before = source.read_bytes()
            with self.assertRaises(Exception):
                self.tool.fix_apk(source, source)
            self.assertEqual(source.read_bytes(), before)
            output.write_bytes(b"protected existing artifact")
            with self.assertRaises(Exception):
                self.tool.fix_apk(source, output)
            self.assertEqual(output.read_bytes(), b"protected existing artifact")


if __name__ == "__main__":
    unittest.main(verbosity=2)
