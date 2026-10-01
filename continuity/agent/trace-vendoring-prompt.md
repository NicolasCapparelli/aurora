# Prompt for the agent working on Trace

Implement this in `C:\Users\cappa\Desktop\Projects\trace`:

Trace currently depends on `../aurora/packages/aurora_flutter`, and the adapter
resolves core from the external Aurora checkout too. Migrate to a committed,
app-owned Aurora snapshot so a fresh Trace checkout builds without a sibling
Aurora source directory. Preserve Trace's existing appearance, typed contract,
theme registry, controller ownership, selection persistence, and navigation.
This is a dependency packaging change.

1. Read Trace's repository instructions and required Continuity context. Preserve
   existing working changes. Read Aurora's
   `C:\Users\cappa\Desktop\Projects\aurora\continuity\user\installation.md`
   for the exporter/update contract. Do not edit Aurora from the Trace task.

2. From Trace, run:

   ```powershell
   python C:\Users\cappa\Desktop\Projects\aurora\tools\vendor.py --project .
   ```

   This creates `vendor/aurora/aurora`, `vendor/aurora/aurora_flutter`,
   `VENDORED.md`, and `vendor-manifest.json`. Keep all of it in Trace's change.
   Use the exporter rather than copying caches, creating links, or editing
   vendored package files. Both packages must remain siblings. The adapter's
   internal `path: ../aurora` now refers to the core inside the snapshot and is
   correct. Preserve `material_color_utilities: 0.11.1` and SDK constraints.
   If an existing destination is encountered, inspect it; `--replace` is only
   for an unchanged managed snapshot. Never delete unrelated vendor contents.

3. Replace Trace's Aurora pubspec dependency with:

   ```yaml
   aurora_flutter:
     path: vendor/aurora/aurora_flutter
   ```

   If Trace has an explicit core dependency, point it to `vendor/aurora/aurora`.
   Check `pubspec_overrides.yaml` and any dependency overrides for remaining
   external Aurora paths. Preserve Entanglement's vendor setup and all unrelated
   dependencies. Existing `package:aurora_flutter/...` imports stay unchanged.
   Run `flutter pub get` and include the updated app lockfile in the change;
   verify both Aurora entries resolve within Trace. Do not commit `.dart_tool`.

4. Add a focused dependency-isolation regression check following Trace's test
   conventions. It should reject external Aurora paths/overrides and verify
   both vendored packages exist with the adapter's core dependency inside the
   snapshot. Treat vendor sources as read-only; respect existing vendor analyzer
   exclusions. Update Trace's comments and affected docs, including
   `continuity/status.md`, `continuity/developer/setup.md`,
   `continuity/developer/architecture.md`, and the agent map's vendor exclusion
   description. Search `README.md`, `docs/design-system.md`, `docs/ui-phase.md`,
   and instructions for any other claims that Aurora must sit next to Trace.
   Keep one documented update command using Aurora's exporter with `--replace`.

5. Run Trace's required checks, including `flutter analyze` and `flutter test`.
   Ensure the existing same-look, theme rules, appearance, and palette tests
   pass. Verify source isolation in a clean copy of the changed Trace tree at a
   temporary location with no sibling `aurora` checkout. Exclude `.git`,
   `.dart_tool`, and build caches; include the new vendor files and updated
   lockfile. Resolve dependencies afresh, inspect both Aurora package root URIs
   to confirm they are inside that copy, then run checks and the applicable
   documented app build. Do not rename/delete the real Aurora checkout. SDKs
   and hosted dependency caches remain normal build prerequisites.

6. Review the final diff and affected Continuity links. Report actual test/build
   results, any environment limits, the exported source revision/dirty state,
   and that Trace no longer needs an external Aurora checkout. A dirty source
   export includes Aurora's current reviewed working changes; its manifest
   hashes record the exact copied files, and HEAD alone is not that snapshot's
   identity. Do not claim that the original Trace app was already verified by
   the Aurora task. Do not commit unless the user separately authorizes it.
