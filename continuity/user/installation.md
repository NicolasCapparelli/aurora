# Install Aurora in an isolated app

This guide covers Flutter and Dart apps. TypeScript apps use
`tools/vendor.py --typescript`; see [consuming from TypeScript](typescript.md#install-an-app-owned-snapshot).

Aurora's packages are currently unpublished. App integrations use committed,
app-owned source snapshots; a build must not require a sibling Aurora checkout.
The source checkout is needed only when initially exporting or updating. The
repository's own adapter/example paths remain appropriate for contributor work.

## Export and wire dependencies

With Python 3 on PATH, run from any directory:

```powershell
python C:\path\to\aurora\tools\vendor.py --project C:\path\to\my_app
```

The app must already contain `pubspec.yaml`. The exporter creates:

```text
vendor/aurora/
  aurora/             # pubspec.yaml, lib/, bin/
  aurora_flutter/     # pubspec.yaml, lib/
  VENDORED.md
  vendor-manifest.json
```

Package README/license files and root license/notice files are included when
present. Tests, caches, build output, package locks, examples, and maintenance
tools are omitted. No package sources or dependency constraints are rewritten.
The adapter depends on its sibling `../aurora`; both packages must stay together.
The core's `material_color_utilities: 0.11.1` pin is preserved.

Update the app's pubspec manually, preserving unrelated entries:

```yaml
dependencies:
  aurora_flutter:
    path: vendor/aurora/aurora_flutter
```

The adapter exports the core API. If the app directly depends on core as well,
use `aurora: {path: vendor/aurora/aurora}`. Pure Dart apps use that core dependency
alone. Remove any old Aurora path overrides in `pubspec.yaml` or
`pubspec_overrides.yaml`. Keep existing `package:` imports and theme code.

Run `flutter pub get` (or `dart pub get`), analyze, and test the app. Commit the
entire vendor directory, pubspec, and app lockfile. Do not commit `.dart_tool`.
Check that the lockfile and resolved package configuration point to both
packages inside the app. Verify a clean copied/checked-out app with no sibling
Aurora directory, resolving dependencies afresh before running checks/builds.
This isolates Aurora source; Flutter/Dart SDKs and normal hosted dependencies
still need to be installed or cached. It does not promise an offline build.

## Review and update a snapshot

The manifest records package versions, source Git HEAD (if available), whether
the source working tree was dirty (null if unavailable), and SHA-256 for each
copied file. HEAD alone does not identify a dirty export: hashes record its
actual contents. Prefer a reviewed clean source revision for releases. No
timestamp or absolute machine path is embedded. Package versions alone are not
unique snapshot identifiers while both packages remain at 0.1.0.

Exporting to an existing directory fails by default. To update:

```powershell
python C:\path\to\aurora\tools\vendor.py --project C:\path\to\my_app --replace
```

Replacement requires a managed snapshot whose files still match its manifest.
Local edits, extra/missing files, symlinks, and Windows junctions are refused.
Preserve/resolve app-local patches in Aurora before retrying. The exporter
stages the complete new snapshot, keeps the old one during the swap, and restores
it if installation fails. Review the vendor diff, resolve app dependencies again,
and rerun app tests before committing the update. No automatic pubspec changes,
dependency resolution, theme installation, commits, or network calls occur.

`--output` selects another app-relative directory if needed; adapt both pubspec
paths accordingly. Escaping paths and destinations inside the Aurora checkout
are refused. Treat vendored files as read-only app inputs. The manifest detects
accidental changes; it is not a signed authenticity guarantee.

The [theme CLI](usage.md) installs generated theme bundles separately into
`lib/aurora_themes`; it does not install or update package dependencies.
