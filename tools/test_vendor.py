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


if __name__ == "__main__":
    unittest.main()
