# Setup

## Prerequisites

- Dart SDK `>=3.6.0 <4.0.0` and Flutter `>=3.27.0` (pubspec constraints). Observed working: Dart 3.9.2, Flutter 3.35.3 on Windows 11.
- PowerShell for `tools/check.ps1`; Python 3 only for `tools/generate_foundation.py`.
- Only external dependency of the core: `material_color_utilities` pinned to `0.11.1` (generator algorithm identity depends on it; see [architecture](architecture.md#generator-and-contrast)).
- No services, secrets, or environment variables. Packages are local (`publish_to: none`); consumers use path dependencies.

## Commands

| Purpose | Working dir | Command | Status |
| --- | --- | --- | --- |
| Full verification (pub get, format check, analyze, tests for all three projects) | repo root | `./tools/check.ps1` | Passed; latest run and scope in [status](../status.md#last-verified-state) |
| Core tests | `packages/aurora` | `dart pub get; dart test` | Passed; counts in status |
| Adapter tests | `packages/aurora_flutter` | `flutter pub get; flutter test` | Passed via check.ps1; counts in status |
| Format check | per package | `dart format --output=none --set-exit-if-changed ...` (path sets are in check.ps1) | Executed via check.ps1 |
| Run example | `examples/theater` | `flutter pub get; flutter run -d chrome` | Inspected, not run |
| Web build (needed when changing demo web integration) | `examples/theater` | `flutter build web` | Inspected, not run |
| Generator UI | `packages/aurora` | `dart run aurora generate [--no-open] [--port N] [--project PATH]` | Inspected, not run |
| Agent/JSON generation | `packages/aurora` | `dart run aurora generate --json --input ../../examples/recipes/theater.json` | CLI exercised with temporary recipes by tests; this example command not run |
| Standalone generator example | `packages/aurora` | `dart run example/generate.dart` | Inspected, not run |
| Regenerate foundation sources | repo root | `python tools/generate_foundation.py` then `dart format packages/aurora/lib packages/aurora_flutter/lib` | Run for status extension and Material mapping; foundation contract unchanged |
| Refresh portable fixture (deliberate only) | `packages/aurora` | `dart run tool/export_portable_fixture.dart` | Not run; never during normal tests |
| Refresh generation fixture (deliberate only) | `packages/aurora` | `dart run tool/export_generation_fixture.dart` | Not run; needs a reviewed algorithm/dependency change |
| Refresh additional scheme fixtures (deliberate only) | `packages/aurora` | `dart run tool/export_scheme_fixture.dart` | Run to create new versioned scheme expectations; never during normal tests |

Core tests read fixtures through relative paths such as `../../spec/fixtures/light.tokens.json`, so they must run from `packages/aurora`.

CLI usage details (global activation, output files, error codes) live in [CLI usage guide](../user/usage.md).

## Troubleshooting

- `pubspec.lock`, `.dart_tool`, and `build` are git-ignored; `pub get` regenerates them.
- Browser does not open from `aurora generate`: open the printed `http://127.0.0.1:<port>/` URL; the server runs until Ctrl+C.
- `--project` fails: the target needs a `pubspec.yaml` listing an `aurora` or `aurora_flutter` dependency; an existing `lib/aurora_themes/<id>` is never overwritten.
- `aurora` short command unavailable: run `dart pub global activate --source path <repo>\packages\aurora` and put Dart's global bin directory on PATH.
- Edits to generated files are overwritten: edit the table in `tools/generate_foundation.py` instead.
