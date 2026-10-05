# Setup

## Prerequisites

- Dart SDK `>=3.6.0 <4.0.0` and Flutter `>=3.27.0` (pubspec constraints). Observed working: Dart 3.9.2, Flutter 3.35.3 on Windows 11.
- Node LTS (22 or newer; observed 24.13.1) with corepack for the TypeScript packages. pnpm is pinned in the root `package.json` and invoked as `corepack pnpm` (a bare `pnpm` may not be on PATH, and `corepack enable` can fail with EPERM).
- PowerShell and Python 3 for `tools/check.ps1` (exporter regression tests); Python 3 also runs `tools/vendor.py` and `tools/generate_foundation.py`.
- Only external dependency of the core: `material_color_utilities` pinned to `0.11.1` (generator algorithm identity depends on it; see [architecture](architecture.md#generator-and-contrast)).
- No services, secrets, or environment variables. Packages are unpublished (`publish_to: none`); apps use [committed vendor snapshots](../user/installation.md) with app-relative path dependencies. Contributor packages/examples use repo-local paths.

## Commands

| Purpose | Working dir | Command | Status |
| --- | --- | --- | --- |
| Full verification (Python exporter tests; TS install, typecheck, tests, build; Dart/Flutter pub get, format check, analyze, tests) | repo root | `./tools/check.ps1` | Passed; latest run and scope in [status](../status.md#last-verified-state) |
| Vendor exporter regression checks (Python 3) | repo root | `python tools/test_vendor.py` | See latest scope in status |
| Core tests | `packages/aurora` | `dart pub get; dart test` | Passed; counts in status |
| TS install / typecheck / tests / build | repo root | `corepack pnpm install --frozen-lockfile`, then `corepack pnpm -r run typecheck`, `-r run test`, `-r run build` | Passed via check.ps1; counts in status |
| Adapter tests | `packages/aurora_flutter` | `flutter pub get; flutter test` | Passed via check.ps1; counts in status |
| Format check | per package | `dart format --output=none --set-exit-if-changed ...` (path sets are in check.ps1) | Executed via check.ps1 |
| Run example | `examples/theater` | `flutter pub get; flutter run -d chrome` | Inspected, not run |
| Web build (needed when changing demo web integration) | `examples/theater` | `flutter build web` | Inspected, not run |
| Generator UI | `packages/aurora` | `dart run aurora generate [--no-open] [--port N] [--project PATH]` | Inspected, not run |
| Agent/JSON generation | `packages/aurora` | `dart run aurora generate --json --input ../../examples/recipes/theater.json` | CLI exercised with temporary recipes by tests; this example command not run |
| Standalone generator example | `packages/aurora` | `dart run example/generate.dart` | Inspected, not run |
| Regenerate foundation sources (Dart and TS) | repo root | `python tools/generate_foundation.py` then `dart format packages/aurora/lib packages/aurora_flutter/lib` | Run when adding the TS target; Dart outputs and `spec/foundation-v1.json` unchanged |
| Refresh portable fixture (deliberate only) | `packages/aurora` | `dart run tool/export_portable_fixture.dart` | Not run; never during normal tests |
| Refresh generation fixture (deliberate only) | `packages/aurora` | `dart run tool/export_generation_fixture.dart` | Not run; needs a reviewed algorithm/dependency change |
| Refresh additional scheme fixtures (deliberate only) | `packages/aurora` | `dart run tool/export_scheme_fixture.dart` | Run to create new versioned scheme expectations; never during normal tests |

Core tests read fixtures through relative paths such as `../../spec/fixtures/light.tokens.json`, so they must run from `packages/aurora`.

CLI usage details (global activation, output files, error codes) live in [CLI usage guide](../user/usage.md).

## Troubleshooting

- `pubspec.lock`, `.dart_tool`, and `build` are git-ignored; `pub get` regenerates them. `node_modules/` and `dist/` are git-ignored; `pnpm-lock.yaml` is committed.
- `pnpm` not recognized: use `corepack pnpm ...`.
- Browser does not open from `aurora generate`: open the printed `http://127.0.0.1:<port>/` URL; the server runs until Ctrl+C.
- `--project` fails: the target needs a `pubspec.yaml` listing an `aurora` or `aurora_flutter` dependency; an existing `lib/aurora_themes/<id>` is never overwritten.
- `aurora` short command unavailable: run `dart pub global activate --source path <repo>\packages\aurora` and put Dart's global bin directory on PATH.
- Edits to generated files are overwritten: edit the table in `tools/generate_foundation.py` instead.
