# Prompt for the TokenSeed agent: integrate Aurora

Paste everything below the line into a Claude Code session opened in the TokenSeed repo (`C:\Users\cappa\Desktop\Projects\tokenseed`).

---

You are working in the TokenSeed repository. Read its own agent instructions first. Then integrate **Aurora**, a sibling theming library at `C:\Users\cappa\Desktop\Projects\aurora` (branch `main`, already merged), in two ways the owner has decided:

1. **Aurora themes TokenSeed's own UI at runtime.** The app chrome takes on the colors of the design system being edited, and gallery thumbnails render different systems side by side using fixed scopes.
2. **TokenSeed exports Aurora bundles** so a Flutter app can install a system made in TokenSeed with one command.

TokenSeed keeps its own generator (OKLCH ramps, display-p3, high-contrast modes, open token tree). Aurora's generator does not replace it. Do not ask for Aurora's foundation or profiles to change; they are fixed, and Aurora's repo is not yours to edit. If you think something in Aurora is wrong or missing, stop and tell the owner.

## Read first (in the Aurora repo)

- `continuity/user/typescript.md`: how to consume `@aurora/core` and `@aurora/react` (install, React provider, fixed scopes, live theming, CSS variable naming, bundles). This is your main guide.
- `spec/bundle-v1.md` and `continuity/user/bundle-producers.md`: the bundle format and what each of the 58 colour roles and 29 texture tokens means, which contrast pairs are diagnosed, and how to handle what Aurora cannot hold.
- `AGENT_ONBOARDING.md` (the "TypeScript and React apps" section) and `continuity/status.md`.

## 1. Vendor Aurora

Aurora is private, never published to npm. From the TokenSeed repo, run:

```
python C:\Users\cappa\Desktop\Projects\aurora\tools\vendor.py --typescript --project C:\Users\cappa\Desktop\Projects\tokenseed\apps\web
```

Decide where the snapshot should live in the pnpm monorepo (the default is `<app>/vendor/aurora/`; the `--output` flag takes another app-relative directory). Add `file:` dependencies on `core` and `react` to the package(s) that use them, install with `corepack pnpm` (on the owner's PC a bare `pnpm` fails), and commit the vendor directory and the lockfile. Make sure only one copy of `@aurora/core` resolves in the whole workspace, because token membership is identity-based. Check the resolved paths. TokenSeed uses TypeScript ~5.9 and Vite 8; confirm the vendored built ESM works with both, including a production build.

## 2. Theme TokenSeed's UI

- Map TokenSeed's systems onto Aurora's contract: generate or construct `AuroraTheme`s with the foundation-only contract (`AuroraBundle.foundationContract`). Sources are TokenSeed's existing tokens; convert OKLCH and display-p3 colors to 8-bit sRGB (clip to gamut). Extra modes such as high contrast and extra tokens do not go into Aurora.
- Wrap the app in `AuroraProvider` (or a fixed scope for the edited system) and restyle the chrome with `var(--aurora-...)` variables.
- Live editing: the chrome follows a system the user is editing, possibly on every slider frame. Use a fixed scope with its `update()` handle, or a changing `variant` prop, so that CSS variables are written imperatively, only the changed ones are rewritten, and the subtree does not re-render. Verify this with a test in TokenSeed.
- Gallery thumbnails: nested `AuroraFixedScope`s, one per system. They must stay cheap with dozens on screen.

## 3. Export bundles

Write an exporter that builds a portable bundle from a TokenSeed system using `AuroraBundle.encode`, with `generator: tokenseed@<version>`, a hash of the source design as `sourceHash`, and an ISO `createdAt`. Include the texture and the suggested pairing when the system has non-colour values. Follow `bundle-producers.md` role by role.

- Run `AuroraBundle.validate` in TokenSeed's own tests on every export, and fail the test on any issue.
- Leave out extra tokens: the strict profiles reject undeclared tokens (the owner confirmed they stay strict).
- Add tests with real TokenSeed systems, including a wide-gamut one and one with a high-contrast mode, and assert the bundle validates and that colors quantize as intended.
- Optionally review contrast with `AuroraContrast.check`; Aurora reports diagnostics and never alters colors.

To verify the Flutter side, install an exported bundle into a scratch Flutter app that depends on a vendored `aurora_flutter` with `dart run aurora install --bundle <file> --project .` and run `flutter analyze` on the registered result. Do not edit the owner's real apps.

## Rules

- Work on a new branch in TokenSeed; commit in logical steps, with TokenSeed's own docs updated. Push the branch. Merging is the owner's call.
- Keep `@aurora/core` imports out of anything that must stay framework-free in TokenSeed's own core package unless that is a deliberate decision you report.
- Run TokenSeed's typecheck, tests and build, and report what passed, what didn't, and anything that needs the owner's decision.
