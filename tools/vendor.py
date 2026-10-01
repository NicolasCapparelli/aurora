#!/usr/bin/env python3
"""Export app-owned Aurora packages without changing the app's pubspec."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import uuid

SOURCE = Path(__file__).resolve().parents[1]
PACKAGES = ("aurora", "aurora_flutter")


def ordinary(path):
    """Refuse links, including Windows junctions, in every existing ancestor."""
    for part in (path, *path.parents):
        try:
            info = part.lstat()
        except FileNotFoundError:
            continue
        # Reparse attributes also cover junctions on Python before is_junction.
        reparse = getattr(info, "st_file_attributes", 0) & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
        if stat.S_ISLNK(info.st_mode) or reparse:
            raise ValueError(f"Linked paths are unsupported: {part}")


def files(root):
    ordinary(root)
    result = {}
    for parent, directories, names in os.walk(root, followlinks=False):
        for name in directories + names:
            ordinary(Path(parent) / name)
        for name in names:
            path = Path(parent) / name
            if not path.is_file():
                raise ValueError(f"Not an ordinary file: {path}")
            result[path.relative_to(root).as_posix()] = path
    return result


def hashes(root):
    return {name: hashlib.sha256(path.read_bytes()).hexdigest()
            for name, path in sorted(files(root).items())
            if name != "vendor-manifest.json"}


def git(*args):
    return subprocess.check_output(
        ["git", "-c", f"safe.directory={SOURCE.as_posix()}", "-C", str(SOURCE), *args],
        text=True, stderr=subprocess.PIPE).strip()


def staging_directory(parent, prefix):
    # mkdir inherits the app's ACLs on Windows. tempfile.mkdtemp uses an
    # owner-only ACL that would survive rename and break builds by other users.
    path = parent / f"{prefix}{uuid.uuid4().hex}"
    path.mkdir()
    return path


def export(project, output="vendor/aurora", replace=False):
    project = Path(os.path.abspath(project))
    ordinary(project)
    if not (project / "pubspec.yaml").is_file():
        raise ValueError("Project needs a pubspec.yaml")
    relative = Path(output)
    if relative.is_absolute() or relative.drive or ".." in relative.parts or not relative.parts:
        raise ValueError("Output must be a relative directory inside the app")
    target = project / relative
    ordinary(target)
    if target == project or target == SOURCE or SOURCE in target.parents:
        raise ValueError("Output must be inside a separate app, outside the Aurora checkout")
    original_manifest = None
    if target.exists():
        if not replace:
            raise ValueError("Destination exists; use --replace for an unchanged managed snapshot")
        manifest_path = target / "vendor-manifest.json"
        if not target.is_dir() or not manifest_path.is_file():
            raise ValueError("Only a managed Aurora snapshot can be replaced")
        original_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        if (not isinstance(original_manifest, dict) or
                original_manifest.get("schemaVersion") != 1 or
                original_manifest.get("files") != hashes(target)):
            raise ValueError("Snapshot has local edits; preserve or resolve them before replacing")
    elif replace:
        raise ValueError("--replace requires an existing managed snapshot")

    # Copy only package inputs, never caches, tests, locks, or development tooling.
    payload = {}
    versions = {}
    for package in PACKAGES:
        root = SOURCE / "packages" / package
        ordinary(root)
        for name in ("pubspec.yaml", "README.md", "LICENSE"):
            path = root / name
            ordinary(path)
            if path.is_file():
                payload[f"{package}/{name}"] = path.read_bytes()
            elif name == "pubspec.yaml":
                raise ValueError(f"Missing {path}")
        for directory in ("lib", "bin"):
            path = root / directory
            if directory == "lib" and not path.is_dir():
                raise ValueError(f"Missing package library: {path}")
            if path.exists():
                for name, file in files(path).items():
                    payload[f"{package}/{directory}/{name}"] = file.read_bytes()
        for line in payload[f"{package}/pubspec.yaml"].decode().splitlines():
            if line.startswith("version:"):
                versions[package] = line.split(":", 1)[1].strip()
    # Preserve any repository-level license/notice if added in the future.
    for name in ("LICENSE", "LICENSE.md", "NOTICE"):
        path = SOURCE / name
        ordinary(path)
        if path.is_file():
            payload[name] = path.read_bytes()
    try:
        revision = git("rev-parse", "HEAD")
        dirty = bool(git("status", "--porcelain", "--untracked-files=all"))
    except (OSError, subprocess.CalledProcessError):
        revision, dirty = None, None
    payload["VENDORED.md"] = (
        "# Vendored Aurora\n\n"
        "App-owned snapshot exported by Aurora tools/vendor.py. Commit this entire directory.\n"
        "Do not edit package files here; update from Aurora with the exporter.\n"
        "Both packages must remain siblings: aurora_flutter depends on ../aurora.\n"
        "vendor-manifest.json records source HEAD, working-tree state, versions, and SHA-256 files.\n"
        "A dirty or unavailable HEAD is not a release identifier; the hashes identify the copied bytes.\n"
        "To update, run the source export command with --replace; local changes are refused.\n"
        "The app pubspec and lockfile are maintained separately. See Aurora's installation guide.\n"
    ).encode()

    target.parent.mkdir(parents=True, exist_ok=True)
    stage = staging_directory(target.parent, ".aurora-export-")
    backup = None
    try:
        for name, content in payload.items():
            path = stage / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
        manifest = {"schemaVersion": 1, "sourceRevision": revision,
                    "sourceDirty": dirty, "packageVersions": versions, "files": hashes(stage)}
        (stage / "vendor-manifest.json").write_text(
            json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        ordinary(target)
        if target.exists():
            # Recheck immediately before replacement, preserving intervening edits.
            if (original_manifest is None or
                    json.loads((target / "vendor-manifest.json").read_text(encoding="utf-8")) != original_manifest or
                    hashes(target) != original_manifest["files"]):
                raise ValueError("Destination changed during export")
            backup = staging_directory(target.parent, ".aurora-backup-")
            backup.rmdir()
            target.rename(backup)
        stage.rename(target)
    except BaseException:
        if backup is not None and backup.exists() and not target.exists():
            backup.rename(target)
        raise
    finally:
        if stage.exists():
            shutil.rmtree(stage)
    if backup is not None:
        shutil.rmtree(backup)
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", required=True, help="App root containing pubspec.yaml")
    parser.add_argument("--output", default="vendor/aurora", help="App-relative destination")
    parser.add_argument("--replace", action="store_true", help="Update an unchanged managed snapshot")
    args = parser.parse_args()
    try:
        target = export(args.project, args.output, args.replace)
    except (ValueError, OSError) as error:
        parser.exit(1, f"Aurora export failed: {error}\n")
    print(f"Exported Aurora to {target}. Commit the snapshot and use app-relative path dependencies.")


if __name__ == "__main__":
    main()
