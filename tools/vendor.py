#!/usr/bin/env python3
"""Export app-owned Aurora packages without changing the app's manifest.

Dart mode (default) copies packages/aurora and packages/aurora_flutter for a
Flutter or Dart app. TypeScript mode (--typescript) builds and copies
@aurora/core and @aurora/react for a pnpm app."""

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
# Source directory, vendored directory name, files copied beside dist/.
TS_PACKAGES = (
    ("aurora_ts", "core", ("README.md", "NOTICE.md", "LICENSE-material-color-utilities")),
    ("aurora_react", "react", ("README.md",)),
)


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


def prepare_target(project, output, replace, kind):
    """Validates the destination; returns (target, manifest being replaced or None)."""
    project = Path(os.path.abspath(project))
    ordinary(project)
    marker = "package.json" if kind == "typescript" else "pubspec.yaml"
    if not (project / marker).is_file():
        raise ValueError(f"Project needs a {marker}")
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
        existing = original_manifest.get("kind", "dart")
        if existing != kind:
            raise ValueError(f"Destination holds a {existing} snapshot, not {kind}")
    elif replace:
        raise ValueError("--replace requires an existing managed snapshot")
    return target, original_manifest


def source_state():
    try:
        return git("rev-parse", "HEAD"), bool(git("status", "--porcelain", "--untracked-files=all"))
    except (OSError, subprocess.CalledProcessError):
        return None, None


def root_notices(payload):
    # Preserve any repository-level license/notice if added in the future.
    for name in ("LICENSE", "LICENSE.md", "NOTICE"):
        path = SOURCE / name
        ordinary(path)
        if path.is_file():
            payload[name] = path.read_bytes()


def install(target, original_manifest, payload, manifest):
    """Stages the payload and manifest beside target, then swaps it in."""
    target.parent.mkdir(parents=True, exist_ok=True)
    stage = staging_directory(target.parent, ".aurora-export-")
    backup = None
    try:
        for name, content in payload.items():
            path = stage / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
        manifest = {**manifest, "files": hashes(stage)}
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


def export(project, output="vendor/aurora", replace=False):
    target, original_manifest = prepare_target(project, output, replace, "dart")

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
    root_notices(payload)
    revision, dirty = source_state()
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
    return install(target, original_manifest, payload,
                   {"schemaVersion": 1, "sourceRevision": revision,
                    "sourceDirty": dirty, "packageVersions": versions})


def corepack(*args):
    executable = shutil.which("corepack")
    if executable is None:
        raise ValueError("corepack was not found on PATH; install a Node.js LTS release")
    return subprocess.run([executable, *args], cwd=SOURCE, check=True,
                          capture_output=True, text=True).stdout.strip()


def build_typescript():
    """Builds both packages in the source checkout; returns the toolchain versions."""
    try:
        corepack("pnpm", "install", "--frozen-lockfile")
        corepack("pnpm", "--filter", "@aurora/core", "--filter", "@aurora/react", "run", "build")
        node = subprocess.run([shutil.which("node") or "node", "--version"],
                              check=True, capture_output=True, text=True).stdout.strip()
        return {"node": node, "pnpm": corepack("pnpm", "--version"),
                "typescript": corepack("pnpm", "--filter", "@aurora/core", "exec", "tsc", "--version")}
    except subprocess.CalledProcessError as error:
        raise ValueError(f"TypeScript build failed: {error.stderr or error.stdout}") from error


def vendored_package_json(path):
    """The package manifest without scripts or development dependencies."""
    data = json.loads(path.read_text(encoding="utf-8"))
    for field in ("scripts", "devDependencies"):
        data.pop(field, None)
    return data


def export_typescript(project, output="vendor/aurora", replace=False, build=None):
    """Exports built ESM plus .d.ts for @aurora/core and @aurora/react.

    Built output rather than source, so the app never compiles Aurora under its
    own tsconfig flags and needs no build configuration for it."""
    target, original_manifest = prepare_target(project, output, replace, "typescript")
    toolchain = (build or build_typescript)()
    payload = {}
    versions = {}
    for package, name, extras in TS_PACKAGES:
        root = SOURCE / "packages" / package
        ordinary(root)
        manifest = root / "package.json"
        ordinary(manifest)
        if not manifest.is_file():
            raise ValueError(f"Missing {manifest}")
        dist = root / "dist"
        if not (dist / "index.js").is_file() or not (dist / "index.d.ts").is_file():
            raise ValueError(f"Missing built package output: {dist}")
        data = vendored_package_json(manifest)
        versions[data["name"]] = data["version"]
        payload[f"{name}/package.json"] = (json.dumps(data, indent=2) + "\n").encode()
        for extra in extras:
            path = root / extra
            ordinary(path)
            if path.is_file():
                payload[f"{name}/{extra}"] = path.read_bytes()
        for relative, file in files(dist).items():
            payload[f"{name}/dist/{relative}"] = file.read_bytes()
    root_notices(payload)
    revision, dirty = source_state()
    payload["VENDORED.md"] = (
        "# Vendored Aurora (TypeScript)\n\n"
        "App-owned snapshot exported by Aurora tools/vendor.py --typescript. Commit this entire directory.\n"
        "core/ is @aurora/core and react/ is @aurora/react, as built ESM with type declarations.\n"
        "Do not edit files here; update from Aurora with the exporter and --replace.\n"
        "Depend on both from the app's package.json with file: specifiers:\n"
        "  \"@aurora/core\": \"file:vendor/aurora/core\"\n"
        "  \"@aurora/react\": \"file:vendor/aurora/react\"\n"
        "@aurora/react takes @aurora/core and react as peer dependencies, so the app's one copy is used.\n"
        "vendor-manifest.json records source HEAD, working-tree state, versions, toolchain and SHA-256 files.\n"
    ).encode()
    return install(target, original_manifest, payload,
                   {"schemaVersion": 1, "kind": "typescript", "sourceRevision": revision,
                    "sourceDirty": dirty, "packageVersions": versions, "toolchain": toolchain})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", required=True,
                        help="App root containing pubspec.yaml (or package.json with --typescript)")
    parser.add_argument("--typescript", action="store_true",
                        help="Build and export @aurora/core and @aurora/react for a pnpm app")
    parser.add_argument("--output", default="vendor/aurora", help="App-relative destination")
    parser.add_argument("--replace", action="store_true", help="Update an unchanged managed snapshot")
    args = parser.parse_args()
    try:
        if args.typescript:
            target = export_typescript(args.project, args.output, args.replace)
        else:
            target = export(args.project, args.output, args.replace)
    except (ValueError, OSError) as error:
        parser.exit(1, f"Aurora export failed: {error}\n")
    dependencies = "file: dependencies" if args.typescript else "app-relative path dependencies"
    print(f"Exported Aurora to {target}. Commit the snapshot and use {dependencies}.")


if __name__ == "__main__":
    main()
