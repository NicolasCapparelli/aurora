# React Native example

A minimal Expo app (Expo ~57.0.26, React 19.2.3, React Native 0.86.3,
TypeScript ~6.0.3, the versions Primer uses) that consumes Aurora only through
an exported `--react-native` snapshot. It shows a managed `AuroraProvider`
following the device appearance, an app colour extension (`example.canvas`), a
texture converted with `view.native` (dashed border, shadow, typography, motion),
a dark `AuroraFixedScope` canvas inside light chrome, and buttons that switch the
theme and the appearance through the controller. It logs
`AURORA_SMOKE mounts=N appearance=... variant=...` so a device run can confirm
that theme changes never remount the tree.

It lives outside the pnpm workspace and is not run by `tools/check.ps1`.

## Get the Aurora snapshot

`vendor/` is git-ignored here, because a committed copy would duplicate and drift
from the package source. The exporter refuses destinations inside the Aurora
checkout, so export into a scratch app and copy the directory in:

```powershell
mkdir $env:TEMP\aurora-rn-scratch; Copy-Item package.json $env:TEMP\aurora-rn-scratch
python ..\..\tools\vendor.py --react-native --project $env:TEMP\aurora-rn-scratch
Copy-Item -Recurse $env:TEMP\aurora-rn-scratch\vendor .\vendor
```

## Run

```powershell
npm install
npm run typecheck          # tsc with TypeScript 6.0.3
npm run bundle:android     # Metro + Hermes bytecode in dist/android
npx expo run:android       # local Gradle build onto a device or emulator
```

`npm ls @aurora/core react` must show one copy of each.
