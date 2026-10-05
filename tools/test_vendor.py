"""Behavioral checks for app-isolated snapshots and safe updates."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import vendor


class VendorTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app = self.root / "app"
        self.app.mkdir()
        (self.app / "pubspec.yaml").write_text("name: app\n")
        self.source = self.root / "source"
        for package in vendor.PACKAGES:
            root = self.source / "packages" / package
            (root / "lib").mkdir(parents=True)
            (root / "lib" / f"{package}.dart").write_text("// original\n")
            (root / "pubspec.yaml").write_text(
                f"name: {package}\nversion: 0.1.0\n" +
                ("dependencies:\n  aurora:\n    path: ../aurora\n"
                 if package == "aurora_flutter" else ""))
            (root / ".dart_tool").mkdir()
            (root / ".dart_tool" / "package_config.json").write_text("cache")
            (root / "pubspec.lock").write_text("lock")
        patcher = patch.object(vendor, "SOURCE", self.source)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_snapshot_survives_source_removal_and_preserves_app(self):
        target = vendor.export(self.app)
        manifest = json.loads((target / "vendor-manifest.json").read_text())
        self.assertEqual(manifest["files"], vendor.hashes(target))
        self.assertEqual(manifest["packageVersions"], {p: "0.1.0" for p in vendor.PACKAGES})
        self.assertIsNone(manifest["sourceRevision"])
        self.source.rename(self.root / "removed-source")
        self.assertTrue((target / "aurora" / "lib" / "aurora.dart").is_file())
        self.assertIn("path: ../aurora", (target / "aurora_flutter" / "pubspec.yaml").read_text())
        self.assertFalse((target / "aurora" / ".dart_tool").exists())
        self.assertFalse((target / "aurora" / "pubspec.lock").exists())
        self.assertEqual((self.app / "pubspec.yaml").read_text(), "name: app\n")

    def test_updates_are_explicit_and_refuse_edits_and_extra_files(self):
        target = vendor.export(self.app)
        with self.assertRaisesRegex(ValueError, "Destination exists"):
            vendor.export(self.app)
        source = self.source / "packages" / "aurora" / "lib" / "aurora.dart"
        source.write_text("// upstream update\n")
        vendor.export(self.app, replace=True)
        copied = target / "aurora" / "lib" / "aurora.dart"
        self.assertEqual(copied.read_text(), source.read_text())
        copied.write_text("// app edit\n")
        with self.assertRaisesRegex(ValueError, "local edits"):
            vendor.export(self.app, replace=True)
        self.assertEqual(copied.read_text(), "// app edit\n")
        copied.write_text(source.read_text())
        (target / "extra.txt").write_text("preserve me")
        with self.assertRaisesRegex(ValueError, "local edits"):
            vendor.export(self.app, replace=True)

    def test_refuses_unmanaged_and_escaping_destinations(self):
        for output in ("../outside", str(self.root / "outside"), "."):
            with self.assertRaises(ValueError):
                vendor.export(self.app, output)
        target = self.app / "vendor" / "aurora"
        target.mkdir(parents=True)
        (target / "keep.txt").write_text("keep")
        with self.assertRaisesRegex(ValueError, "managed"):
            vendor.export(self.app, replace=True)
        self.assertEqual((target / "keep.txt").read_text(), "keep")

    def test_failed_install_restores_previous_snapshot(self):
        target = vendor.export(self.app)
        before = vendor.hashes(target)
        rename = Path.rename

        def fail_stage(path, destination):
            if path.name.startswith(".aurora-export-"):
                raise OSError("simulated rename failure")
            return rename(path, destination)

        with patch.object(Path, "rename", fail_stage):
            with self.assertRaisesRegex(OSError, "simulated"):
                vendor.export(self.app, replace=True)
        self.assertEqual(vendor.hashes(target), before)
        self.assertEqual(list(target.parent.glob(".aurora-*")), [])

    def test_refuses_invalid_manifest_and_missing_source_library(self):
        target = vendor.export(self.app)
        (target / "vendor-manifest.json").write_text("[]")
        with self.assertRaisesRegex(ValueError, "local edits"):
            vendor.export(self.app, replace=True)
        (self.source / "packages" / "aurora" / "lib").rename(self.source / "removed-lib")
        with self.assertRaisesRegex(ValueError, "Missing package library"):
            vendor.export(self.app, "vendor/second")
        self.assertFalse((self.app / "vendor" / "second").exists())

    def test_refuses_links_in_destination_and_source(self):
        link = self.app / "linked"
        outside = self.root / "outside"
        outside.mkdir()
        try:
            link.symlink_to(outside, target_is_directory=True)
        except OSError:
            self.skipTest("Symlink creation unavailable on this host")
        with self.assertRaisesRegex(ValueError, "Linked"):
            vendor.export(self.app, "linked/aurora")
        source_link = self.source / "packages" / "aurora" / "lib" / "linked.dart"
        source_link.symlink_to(self.app / "pubspec.yaml")
        with self.assertRaisesRegex(ValueError, "Linked"):
            vendor.export(self.app)

    @unittest.skipUnless(os.name == "nt", "Windows junction behavior")
    def test_refuses_windows_junction_parent(self):
        outside = self.root / "outside"
        outside.mkdir()
        junction = self.app / "junction"
        result = subprocess.run(
            ["cmd", "/c", "mklink", "/J", str(junction), str(outside)],
            capture_output=True, text=True)
        if result.returncode:
            self.skipTest(f"Junction creation unavailable: {result.stderr}")
        with self.assertRaisesRegex(ValueError, "Linked"):
            vendor.export(self.app, "junction/aurora")
        self.assertEqual(list(outside.iterdir()), [])


class TypeScriptVendorTest(unittest.TestCase):
    TOOLCHAIN = {"node": "v24", "pnpm": "10.28.0", "typescript": "Version 5.9.3"}

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app = self.root / "app"
        self.app.mkdir()
        (self.app / "package.json").write_text('{"name": "app"}')
        self.source = self.root / "source"
        for package, name, _ in vendor.TS_PACKAGES:
            root = self.source / "packages" / package
            (root / "dist").mkdir(parents=True)
            (root / "dist" / "index.js").write_text("export {};\n")
            (root / "dist" / "index.d.ts").write_text("export {};\n")
            (root / "src").mkdir()
            (root / "src" / "index.ts").write_text("// source\n")
            (root / "node_modules").mkdir()
            (root / "README.md").write_text(name)
            (root / "package.json").write_text(json.dumps({
                "name": f"@aurora/{name}", "version": "0.1.0", "private": True,
                "scripts": {"build": "tsc"}, "devDependencies": {"typescript": "~5.9.3"},
                **({"peerDependencies": {"@aurora/core": "0.1.0", "react": "^19.0.0"}}
                   if name == "react" else {})}))
        patcher = patch.object(vendor, "SOURCE", self.source)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.builds = 0

    def build(self):
        self.builds += 1
        return self.TOOLCHAIN

    def test_exports_built_packages_with_provenance(self):
        target = vendor.export_typescript(self.app, build=self.build)
        self.assertEqual(self.builds, 1)
        manifest = json.loads((target / "vendor-manifest.json").read_text())
        self.assertEqual(manifest["kind"], "typescript")
        self.assertEqual(manifest["toolchain"], self.TOOLCHAIN)
        self.assertEqual(manifest["packageVersions"], {"@aurora/core": "0.1.0", "@aurora/react": "0.1.0"})
        self.assertEqual(manifest["files"], vendor.hashes(target))
        self.assertTrue((target / "core" / "dist" / "index.d.ts").is_file())
        self.assertFalse((target / "core" / "src").exists())
        self.assertFalse((target / "core" / "node_modules").exists())
        react = json.loads((target / "react" / "package.json").read_text())
        self.assertNotIn("scripts", react)
        self.assertNotIn("devDependencies", react)
        self.assertEqual(react["peerDependencies"]["@aurora/core"], "0.1.0")
        self.assertEqual((self.app / "package.json").read_text(), '{"name": "app"}')

    def test_updates_are_explicit_and_refuse_edits(self):
        target = vendor.export_typescript(self.app, build=self.build)
        with self.assertRaisesRegex(ValueError, "Destination exists"):
            vendor.export_typescript(self.app, build=self.build)
        vendor.export_typescript(self.app, replace=True, build=self.build)
        (target / "core" / "dist" / "index.js").write_text("// app edit\n")
        with self.assertRaisesRegex(ValueError, "local edits"):
            vendor.export_typescript(self.app, replace=True, build=self.build)

    def test_refuses_missing_build_output_and_wrong_project(self):
        (self.source / "packages" / "aurora_react" / "dist" / "index.d.ts").unlink()
        with self.assertRaisesRegex(ValueError, "Missing built package output"):
            vendor.export_typescript(self.app, build=self.build)
        self.assertFalse((self.app / "vendor").exists())
        dart_app = self.root / "dart_app"
        dart_app.mkdir()
        (dart_app / "pubspec.yaml").write_text("name: app\n")
        with self.assertRaisesRegex(ValueError, "package.json"):
            vendor.export_typescript(dart_app, build=self.build)

    def test_refuses_to_replace_a_dart_snapshot(self):
        (self.app / "pubspec.yaml").write_text("name: app\n")
        for package in vendor.PACKAGES:
            root = self.source / "packages" / package
            (root / "lib").mkdir(parents=True)
            (root / "pubspec.yaml").write_text(f"name: {package}\nversion: 0.1.0\n")
        vendor.export(self.app)
        with self.assertRaisesRegex(ValueError, "dart snapshot"):
            vendor.export_typescript(self.app, replace=True, build=self.build)


class ReactNativeVendorTest(unittest.TestCase):
    TOOLCHAIN = {"node": "v24", "pnpm": "10.28.0", "typescript": "Version 5.9.3"}
    PEERS = {
        "core": {},
        "react": {"@aurora/core": "0.1.0", "react": "^19.0.0"},
        "react-native": {"@aurora/core": "0.1.0", "react": ">=19.0.0 <20", "react-native": ">=0.79.0"},
    }

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app = self.root / "app"
        self.app.mkdir()
        (self.app / "package.json").write_text('{"name": "app"}')
        self.source = self.root / "source"
        for package, name, _ in (*vendor.TS_PACKAGES, vendor.RN_PACKAGES[1]):
            root = self.source / "packages" / package
            (root / "dist").mkdir(parents=True)
            (root / "dist" / "index.js").write_text("export {};\n")
            (root / "dist" / "index.d.ts").write_text("export {};\n")
            (root / "src").mkdir()
            (root / "node_modules").mkdir()
            (root / "README.md").write_text(name)
            data = {"name": f"@aurora/{name}", "version": "0.1.0", "private": True,
                    "scripts": {"build": "tsc"}, "devDependencies": {"@aurora/core": "workspace:*"}}
            if self.PEERS[name]:
                data["peerDependencies"] = self.PEERS[name]
            (root / "package.json").write_text(json.dumps(data))
        patcher = patch.object(vendor, "SOURCE", self.source)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.builds = 0

    def build(self):
        self.builds += 1
        return self.TOOLCHAIN

    def test_exports_core_and_react_native_only(self):
        target = vendor.export_react_native(self.app, build=self.build)
        self.assertEqual(self.builds, 1)
        manifest = json.loads((target / "vendor-manifest.json").read_text())
        self.assertEqual(manifest["kind"], "react-native")
        self.assertEqual(manifest["toolchain"], self.TOOLCHAIN)
        self.assertEqual(manifest["packageVersions"], {"@aurora/core": "0.1.0", "@aurora/react-native": "0.1.0"})
        self.assertEqual(manifest["files"], vendor.hashes(target))
        self.assertEqual(sorted(p.name for p in target.iterdir() if p.is_dir()), ["core", "react-native"])
        self.assertFalse((target / "react").exists())
        self.assertTrue((target / "react-native" / "dist" / "index.d.ts").is_file())
        self.assertFalse((target / "react-native" / "src").exists())
        package = json.loads((target / "react-native" / "package.json").read_text())
        self.assertNotIn("scripts", package)
        self.assertNotIn("devDependencies", package)
        self.assertEqual(package["peerDependencies"]["@aurora/core"], "0.1.0")
        self.assertIn("file:vendor/aurora/react-native", (target / "VENDORED.md").read_text())
        self.assertEqual((self.app / "package.json").read_text(), '{"name": "app"}')

    def test_workspace_runtime_dependencies_become_file_siblings(self):
        path = self.source / "packages" / "aurora_react_native" / "package.json"
        data = json.loads(path.read_text())
        data["dependencies"] = {"@aurora/core": "workspace:*"}
        path.write_text(json.dumps(data))
        target = vendor.export_react_native(self.app, build=self.build)
        package = json.loads((target / "react-native" / "package.json").read_text())
        self.assertEqual(package["dependencies"], {"@aurora/core": "file:../core"})
        data["dependencies"] = {"left-pad": "workspace:*"}
        path.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, "unresolved"):
            vendor.export_react_native(self.app, "second", build=self.build)

    def test_replace_unchanged_works_and_edits_are_refused(self):
        target = vendor.export_react_native(self.app, build=self.build)
        with self.assertRaisesRegex(ValueError, "Destination exists"):
            vendor.export_react_native(self.app, build=self.build)
        vendor.export_react_native(self.app, replace=True, build=self.build)
        self.assertEqual(self.builds, 2)
        (target / "react-native" / "dist" / "index.js").write_text("// app edit\n")
        with self.assertRaisesRegex(ValueError, "local edits"):
            vendor.export_react_native(self.app, replace=True, build=self.build)

    def test_refuses_replacing_a_snapshot_of_another_kind_in_both_directions(self):
        vendor.export_react_native(self.app, build=self.build)
        with self.assertRaisesRegex(ValueError, "react-native snapshot, not typescript"):
            vendor.export_typescript(self.app, replace=True, build=self.build)
        other = self.root / "other"
        other.mkdir()
        (other / "package.json").write_text('{"name": "other"}')
        vendor.export_typescript(other, build=self.build)
        with self.assertRaisesRegex(ValueError, "typescript snapshot, not react-native"):
            vendor.export_react_native(other, replace=True, build=self.build)

    def test_refuses_missing_build_output_and_wrong_project(self):
        (self.source / "packages" / "aurora_react_native" / "dist" / "index.d.ts").unlink()
        with self.assertRaisesRegex(ValueError, "Missing built package output"):
            vendor.export_react_native(self.app, build=self.build)
        self.assertFalse((self.app / "vendor").exists())
        dart_app = self.root / "dart_app"
        dart_app.mkdir()
        (dart_app / "pubspec.yaml").write_text("name: app\n")
        with self.assertRaisesRegex(ValueError, "package.json"):
            vendor.export_react_native(dart_app, build=self.build)

    def test_command_line_rejects_both_modes(self):
        with patch("sys.argv", ["vendor.py", "--project", str(self.app), "--typescript", "--react-native"]):
            with self.assertRaises(SystemExit) as raised:
                vendor.main()
        self.assertEqual(raised.exception.code, 2)
        self.assertFalse((self.app / "vendor").exists())


if __name__ == "__main__":
    unittest.main()
