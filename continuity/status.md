# Status

## Current state

- All three packages and the example are present and, per the last check run, format-clean, analyzer-clean, and passing tests (see Last verified state). Nothing is known to be broken.
- Core (`packages/aurora`): contracts, themes, runtime, DTCG, generator, recipe, CLI, and tooling are implemented in source and exercised by tests.
- Adapter (`packages/aurora_flutter`): controller, scope, engine, Material bridge implemented and exercised by widget tests.
- App-owned package distribution is implemented by `tools/vendor.py`; installation/onboarding use committed in-app snapshots. See [installation](user/installation.md).
- Not exercised in this session: `flutter build web`, `flutter run`, browser UI in a real browser, theme installer against a real app. CLI and theme installer run against temporary projects in tests.
- Implemented scope is color tokens only; other token types, persistence, resolver packaging, contract codegen, and a TypeScript port are planned/unimplemented ([design notes](decisions/design-notes.md)).

## Active work and last stopping point

- **No active Aurora work. Trace migration is handed off.** Package vendoring, documentation, tests, and the prompt are included in this commit at the user's request. Trace has not been edited. See [Trace migration prompt](agent/trace-vendoring-prompt.md).
- Investigation confirmed Trace's pubspec, lockfile, and resolved package configuration point to the sibling Aurora checkout. Aurora's former onboarding instructed that integration. The new exporter copies both packages without caches, preserves internal sibling paths, records revision/dirty state/versions/SHA-256, and refuses overwrite or modified snapshots unless an unchanged managed export is explicitly replaced. No runtime APIs changed.
- Implemented: controller-free fixed scopes; foundation-only per-seed snapshots; nine pinned generation schemes in Dart, recipes, and browser UI; synchronous Flutter notifications and initial platform brightness; selection JSON/restoration; Flutter conversions; contract getter; readable foreground and diagnostic report helpers; generated native status colors; installer registration snippets; onboarding recipes. Typed app-token reads already existed and are clarified rather than replaced with contract codegen.
- The prior integration-feedback commit includes the `docs/` migration into Continuity alongside implementation, tests, new scheme fixtures, and affected documentation. Original generation fixtures and required foundation roles are unchanged. That earlier task left no intended uncommitted work; the package-vendoring changes described above are new.

## Next steps and context

Requested downstream work: the agent in Trace implements the [migration prompt](agent/trace-vendoring-prompt.md) and verifies that app. No further Aurora task established. Optional candidates (not selected): see "Next milestones" in [README](../README.md) and "Next design questions" in [design notes](decisions/design-notes.md). Start from the [agent map](agent/map.md).

## Blockers and open questions

- None blocking. Migration is complete with exceptions: root README, AGENT_ONBOARDING.md, AGENTS.md, and `spec/` intentionally stay in place (see [architecture](developer/architecture.md#documentation-ownership)). Whether `spec/` should also move is the user's call; it was kept because fixtures/tools use fixed paths.
- Unknown (future-work only): intended foundation versioning policy when adding tokens ([AGENTS.md](../AGENTS.md) says it needs a decision).

## Last verified state

2026-10-01, package-vendoring implementation included in this commit:

- Final `./tools/check.ps1`: exit 0; 7 Python exporter tests (including Windows junction rejection), formatting/analysis, 73 core tests, and 22 Flutter tests pass; theater analyzed.
- Exporter tests cover source removal, sibling dependency retention/cache exclusion, explicit updates, local edits/extra files, unmanaged/escaping destinations, invalid manifests/missing source, symlink/junction rejection, and rollback after failed installation. Export directories inherit the app's permissions, verified by a consumer running under a different Windows account.
- Separate Flutter consumer outside the Aurora checkout (no sibling source directory) resolves both packages from its own vendor snapshot and passes `flutter pub get`, `flutter analyze`, and a Flutter smoke test exercising generation and Material mapping for both appearances. Fresh package configuration points to `../vendor/aurora/aurora` and `../vendor/aurora/aurora_flutter` relative to `.dart_tool`. This verifies the package export, not Trace's integration or a platform app build.
- No Trace files changed and no Trace tests/builds run. No demo web integration changes or web build. Implementation verification predates the final commit-status-only documentation update; implementation is unchanged.
- Implementation/docs/handoff diff reviewed; `git diff --check` passed. All 171 relative documentation links/anchors in 17 documents resolved after the handoff documentation updates.

2026-10-01, implementation included in this handoff commit:

- `./tools/check.ps1`: exit 0; dependencies resolved, formatting and analysis passed for core, adapter, and theater; 73 core tests and 22 Flutter tests passed.
- Flutter same-look regression compares all 46 supported Material roles for three seeds, nine schemes, and both appearances. Default portable generation fixtures pass unchanged. New versioned scheme fixtures are read by normal tests; only their explicit maintenance export was run to create them.
- Installer tests compile/execute the returned registration snippet in a temporary project and preserve required-extension rejection. Controller and fixed-scope widget regressions pass.
- Foundation sources regenerated from `tools/generate_foundation.py` and formatted. No foundation token/version change. No demo web integration edits, so web build was not run.
- Browser UI source/server inputs changed and server/generation tests passed; visual browser interaction was not exercised. Trace was not modified or re-tested; this request changed Aurora.
- Commit/handoff review: relevant implementation and staged diffs reviewed; whitespace checks passed; all 159 relative documentation paths/anchors in 19 documents resolved after the final Continuity updates.

Earlier verification history:

Date 2026-09-30, base commit `0e782d2` with only untracked `continuity/` and documentation edits (no source changes):

- `./tools/check.ps1` from the root: exit 0 (pub get, format check, analyze, tests in all three projects).
- Core `dart test` in `packages/aurora`: 59 tests passed. Flutter `flutter test` in `packages/aurora_flutter`: 17 tests passed. `examples/theater` has no `test/` dir; analyzed only.
- Not run: `flutter build web` (examples/theater), `flutter run -d chrome`, `dart run aurora generate` (browser/server), `python tools/generate_foundation.py`, `dart run tool/export_*_fixture.dart` (these refresh checked-in fixtures; do not run casually).
- After the documentation migration (docs moved, links repaired), `./tools/check.ps1` was re-run: exit 0. A script confirmed all relative links/anchors in Continuity, `AGENTS.md`, `README.md`, `AGENT_ONBOARDING.md`, and the two edited spec files resolve. The only remaining mention of `continuity/migrate.md` is generic explanatory text in `about.md`.
- Counts are as observed; no historical count was compared.

## Last meaningful update

2026-10-01 — App-owned package snapshots replace external-checkout installation guidance; exporter, integrity checks, regression tests, and Trace migration prompt included in this commit at the user's request. No further Aurora task established.

2026-10-01 — Integration-feedback implementation and Continuity migration committed at the user's request; repository checks passed on the implementation before the final status-only documentation update.
