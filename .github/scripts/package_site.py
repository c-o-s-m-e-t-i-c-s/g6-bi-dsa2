#!/usr/bin/env python3
"""Validate and package deploy/site as a bounded, regular-files-only tar.gz."""
from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import tarfile
import tempfile

ALLOWED = {
    ".html", ".htm", ".css", ".js", ".mjs", ".cjs", ".map", ".json",
    ".webmanifest", ".xml", ".txt", ".svg", ".png", ".jpg", ".jpeg",
    ".gif", ".webp", ".avif", ".ico", ".woff", ".woff2", ".ttf",
    ".otf", ".eot", ".mp3", ".mp4", ".webm", ".ogg", ".wav", ".wasm",
    ".pdf",
}
MAX_ARCHIVE = 64 * 1024 * 1024
MAX_EXPANDED = 128 * 1024 * 1024
MAX_FILES = 5000
ASSET_PATH = re.compile(r"site/(?:[A-Za-z0-9_-][A-Za-z0-9._-]*/)*[A-Za-z0-9_-][A-Za-z0-9._-]*")


def fail(message: str) -> None:
    raise SystemExit(f"package_site: {message}")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--root", default=".")
    p.add_argument("--out", default="artifact/site.tar.gz")
    p.add_argument("--slug", required=True)
    p.add_argument("--repository-id", required=True)
    p.add_argument("--revision", required=True)
    p.add_argument("--ref", required=True)
    p.add_argument("--run-id", required=True)
    p.add_argument("--run-attempt", required=True)
    a = p.parse_args()

    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", a.slug):
        fail("invalid project slug")
    if not re.fullmatch(r"[0-9a-f]{40}", a.revision):
        fail("revision must be a full hexadecimal commit SHA")
    if not a.repository_id.isdigit() or not a.run_id.isdigit() or not a.run_attempt.isdigit():
        fail("repository id, run id, and run attempt must be numeric strings")

    root = Path(a.root).resolve()
    site = root / "deploy" / "site"
    if not site.is_dir() or not (site / "index.html").is_file():
        fail("deploy/site/index.html is required")
    if not stat.S_ISDIR((root / "deploy").lstat().st_mode) or not stat.S_ISDIR(site.lstat().st_mode):
        fail("deploy and deploy/site must be regular directories")
    files: list[tuple[Path, str, int]] = []
    expanded = 0
    for base, dirs, names in os.walk(site, followlinks=False):
        base_path = Path(base)
        # Exclude every dot directory, and reject symlinks/special files rather than following them.
        visible_dirs = []
        for d in dirs:
            if d.startswith("."):
                continue
            directory = base_path / d
            if not stat.S_ISDIR(directory.lstat().st_mode):
                fail(f"only regular directories are allowed: {directory.relative_to(site).as_posix()}")
            visible_dirs.append(d)
        dirs[:] = sorted(visible_dirs)
        for name in sorted(names):
            src = base_path / name
            rel = src.relative_to(site).as_posix()
            if any(part.startswith(".") for part in PurePosixPath(rel).parts):
                continue
            try:
                st = src.lstat()
            except OSError as e:
                fail(f"cannot inspect {rel}: {e}")
            if not stat.S_ISREG(st.st_mode):
                fail(f"only regular files are allowed: {rel}")
            if src.suffix.lower() not in ALLOWED:
                fail(f"disallowed file extension: {rel}")
            if len(rel) > 235 or not ASSET_PATH.fullmatch(f"site/{rel}"):
                fail(f"invalid asset path: {rel}")
            files.append((src, rel, st.st_size))
            expanded += st.st_size
    if len(files) == 0 or len(files) > MAX_FILES:
        fail(f"file count must be between 1 and {MAX_FILES}")
    if expanded > MAX_EXPANDED:
        fail("expanded site exceeds 128 MiB")
    if not any(rel == "index.html" and size > 0 for _, rel, size in files):
        fail("index.html must be a non-empty regular file at the site root")

    manifest = {
        "format": 1,
        "project": a.slug,
        "repository_id": str(a.repository_id),
        "revision": a.revision,
        "ref": a.ref,
        "run_id": str(a.run_id),
        "run_attempt": str(a.run_attempt),
    }
    out = Path(a.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=out.parent, suffix=".tar.gz", delete=False) as tmp:
        temp_name = tmp.name
    try:
        with tarfile.open(temp_name, "w:gz", format=tarfile.PAX_FORMAT) as tf:
            info = tarfile.TarInfo("manifest.json")
            raw = (json.dumps(manifest, sort_keys=True, separators=(",", ":")) + "\n").encode()
            info.size, info.mode, info.mtime = len(raw), 0o644, 0
            tf.addfile(info, io.BytesIO(raw))
            for src, rel, size in files:
                info = tarfile.TarInfo(f"site/{rel}")
                info.size, info.mode, info.mtime = size, 0o644, 0
                with src.open("rb") as f:
                    tf.addfile(info, f)
        if Path(temp_name).stat().st_size > MAX_ARCHIVE:
            fail("compressed archive exceeds 64 MiB")
        with gzip.open(temp_name, "rb") as archive:
            expanded_size = sum(len(block) for block in iter(lambda: archive.read(1024 * 1024), b""))
        if expanded_size > MAX_EXPANDED:
            fail("expanded archive exceeds 128 MiB including tar headers")
        os.replace(temp_name, out)
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)
    digest = hashlib.sha256(out.read_bytes()).hexdigest()
    print(f"archive={out} sha256={digest} files={len(files)} expanded_bytes={expanded}")


if __name__ == "__main__":
    main()
