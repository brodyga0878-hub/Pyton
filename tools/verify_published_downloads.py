#!/usr/bin/env python3
"""Read-only HTTPS verification of the two immutable StarFrontier packages.

Uses normal inherited proxy and CA settings. Never pushes, uploads, modifies
release payloads, rebuilds an APK, or changes GitHub settings.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import hashlib
import json
from pathlib import Path
import urllib.request
import zipfile
from zoneinfo import ZoneInfo

PROJECT = Path(__file__).resolve().parents[1]
REPOSITORY = "brodyga0878-hub/Pyton"
PACKAGES = (
    {
        "version": "0.12.0-worlds-alpha1",
        "artifact_commit": "3eb5e6061dc99c11c6215f338faef5d2376588c1",
        "source_commit": "0233a8c012ebf71337afe1395073cd1400e90b9e",
        "payloads": (
            "StarFrontier-0.12.0-worlds-arm64.apk",
            "StarFrontier-0.12.0-worlds-source.zip",
        ),
    },
    {
        "version": "0.12.1-console-alpha1",
        "artifact_commit": "09b48fc9829e40bef133b4a996c110b7ca4881cf",
        "source_commit": "932d641055f4fb587d4dd278ad986804b63dd754",
        "payloads": (
            "StarFrontier-0.12.1-console-arm64.apk",
            "StarFrontier-0.12.1-console-source.zip",
            "screenshots/05-classic-console-wide-landscape.png",
            "screenshots/capture-manifest.json",
        ),
    },
)


def base_url(package: dict) -> str:
    return (
        f"https://raw.githubusercontent.com/{REPOSITORY}/"
        f"{package['artifact_commit']}/deliverables/{package['version']}/"
    )


def download(url: str, target: Path, expected: dict) -> dict:
    """Download complete bytes; validate length and SHA before atomic naming."""
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_name(target.name + ".download")
    digest = hashlib.sha256()
    count = 0
    request = urllib.request.Request(url, headers={"User-Agent": "StarFrontier-release-verifier/1"})
    with urllib.request.urlopen(request, timeout=45) as response, temporary.open("wb") as stream:
        if response.status != 200 or response.geturl() != url:
            raise ValueError(f"Unexpected response or redirect for {url}")
        content_type = response.headers.get("Content-Type", "")
        content_length = response.headers.get("Content-Length")
        while chunk := response.read(1024 * 1024):
            stream.write(chunk)
            digest.update(chunk)
            count += len(chunk)
            if count > expected["bytes"]:
                raise ValueError(f"Response exceeds expected payload length: {url}")
    sha256 = digest.hexdigest()
    if count != expected["bytes"] or sha256 != expected["sha256"]:
        raise ValueError(f"Byte count or SHA-256 mismatch for {url}")
    if content_length is not None and int(content_length) != count:
        raise ValueError(f"Content-Length mismatch for {url}")
    temporary.replace(target)
    return {
        "url": url,
        "http_status": 200,
        "bytes": count,
        "sha256": sha256,
        "content_type": content_type,
        "downloaded_to": str(target),
        "matches_local_immutable_payload": True,
    }


def verify_payload(package: dict, name: str, manifest: dict, output: Path) -> tuple[str, dict]:
    target = output / package["version"] / name
    result = download(base_url(package) + name, target, manifest["files"][name])
    if name.endswith((".apk", ".zip")):
        with zipfile.ZipFile(target) as archive:
            damaged = archive.testzip()
            if damaged is not None:
                raise ValueError(f"Invalid ZIP CRC in {name}: {damaged}")
            result["zip_crc_verified"] = True
            if name.endswith("-source.zip"):
                if archive.comment.decode("ascii") != package["source_commit"]:
                    raise ValueError(f"Source commit comment mismatch in {name}")
                count = sum(not entry.is_dir() for entry in archive.infolist())
                if count != manifest["source_archive_files"]:
                    raise ValueError(f"Source archive file count mismatch in {name}")
                result["source_commit_in_zip_comment"] = package["source_commit"]
                result["source_file_count"] = count
    print(f"PASS {package['version']}/{name}: HTTP200 {result['bytes']} bytes SHA256={result['sha256']}", flush=True)
    return name, result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--download-dir", type=Path, default=Path("/workspace/recovery/published-downloads-2026-11-07"))
    parser.add_argument("--proof-dir", type=Path, default=PROJECT / "validation/publication-2026-11-07")
    args = parser.parse_args()
    args.proof_dir.mkdir(parents=True, exist_ok=True)
    proof = {
        "started_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "repository": REPOSITORY,
        "scope": "Actual independent complete HTTPS downloads from immutable Git commit URLs; downloaded manifests also match local immutable manifests. Four full APK/source ZIP payloads have SHA256/length/ZIP CRC controls; both source ZIP comments identify exact source commits. The current console screenshot and capture manifest are downloaded and hash-checked as well.",
        "network_operation": "read_only_https_get",
        "upload_performed_by_this_tool": False,
        "complete_manifest_payloads_downloaded": False,
        "physical_device_tested": False,
        "complete_original_ffe_claimed": False,
        "packages": {},
        "errors": [],
    }
    try:
        for package in PACKAGES:
            local = PROJECT / "deliverables" / package["version"] / "manifest.json"
            local_bytes = local.read_bytes()
            local_manifest = json.loads(local_bytes)
            expected = {"bytes": len(local_bytes), "sha256": hashlib.sha256(local_bytes).hexdigest()}
            manifest_result = download(
                base_url(package) + "manifest.json",
                args.download_dir / package["version"] / "manifest.json",
                expected,
            )
            remote_manifest = json.loads((args.download_dir / package["version"] / "manifest.json").read_text())
            if remote_manifest != local_manifest or remote_manifest["source_commit"] != package["source_commit"]:
                raise ValueError(f"Source identity mismatch: {package['version']}")
            entry = {
                "artifact_commit": package["artifact_commit"],
                "source_commit": package["source_commit"],
                "manifest": manifest_result,
                "files": {},
            }
            proof["packages"][package["version"]] = entry
            with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
                futures = [executor.submit(verify_payload, package, name, remote_manifest, args.download_dir) for name in package["payloads"]]
                for future in concurrent.futures.as_completed(futures):
                    name, result = future.result()
                    entry["files"][name] = result
        proof["status"] = "passed"
    except Exception as error:
        proof["status"] = "failed"
        proof["errors"].append({"type": type(error).__name__, "message": str(error)[:1500]})
        print(f"FAIL {type(error).__name__}: {error}", flush=True)
    proof["verified_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
    proof["verified_moscow"] = dt.datetime.now(ZoneInfo("Europe/Moscow")).isoformat()
    proof["verified_file_count"] = sum(len(p["files"]) + 1 for p in proof["packages"].values())
    path = args.proof_dir / "remote-download-verification.json"
    path.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n")
    print(f"Saved {proof['status']} verification: {path}", flush=True)
    return 0 if proof["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
