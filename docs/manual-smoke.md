# Manual Smoke Checklist

Use this checklist before tagging a release or claiming compatibility for a new
system image revision. The automated suite proves the modular layout, parser,
mocked ADB flow, bundle generation, and shell quality gates; these checks prove
the real host/emulator workflow.

Record completed results with
[docs/manual-smoke-results-template.md](manual-smoke-results-template.md).

## Preflight

- Run `tools/check.sh`.
- Confirm `git status --short` only shows intentional source, docs, test, or
  generated-artifact changes.
- Confirm `ANDROID_HOME` points to the SDK that owns the AVD system images.
- Start exactly one target AVD unless a step says otherwise.
- Keep the original `ramdisk.img`, `kernel-ranchu`, and module artifacts
  restorable through the normal rootAVD backup/restore flow.

## Non-Destructive Checks

- Run `tools/smoke-nondestructive.sh` to build the bundle, compare source and
  bundle `ListAllAVDs`, and smoke-test `restore` and `toggleRamdisk` against a
  temporary SDK tree.
- Run `tools/smoke-adb-load.sh` with one AVD connected to push source and
  bundle payloads into `/data/local/tmp`, run `SOURCING DEBUG`, and clean up.
- Run `./rootAVD.sh ListAllAVDs` from the source checkout.
- Run `tools/build-rootavd-bundle.sh`.
- Run `dist/rootAVD.sh ListAllAVDs`.
- Run `./rootAVD.sh InstallApps` with no APK files in `Apps/`; this should
  exercise ADB discovery and exit without trying to install `Apps/.gitkeep`.
- If `tools/smoke-adb-load.sh` is unavailable, manually push source mode
  `rootAVD.sh` and `lib/rootavd/*.sh` to a temporary AVD shell directory and
  run `sh rootAVD.sh SOURCING DEBUG`.
- If `tools/smoke-adb-load.sh` is unavailable, manually push only
  `dist/rootAVD.sh` to a temporary AVD shell directory as `rootAVD.sh` and run
  `sh rootAVD.sh SOURCING DEBUG`.

## API 36.1 Release Matrix

Run the normal patch flow for each tested Google Play Store system image.

| System Image | Architecture | Required Smoke |
| --- | --- | --- |
| Google Play Store API 36.1 | `arm64-v8a` | `./rootAVD.sh <system-image>/ramdisk.img` |
| Google Play Store API 36.1 | `x86_64` | `./rootAVD.sh <system-image>/ramdisk.img` |

For each architecture:

- Verify the script reaches the emulator flow through ADB.
- Verify Magisk/BusyBox preparation completes.
- Verify the patched ramdisk is pulled back to the host.
- Boot the AVD again and verify Magisk can be launched.
- Run `./rootAVD.sh <system-image>/ramdisk.img restore` and verify the original
  ramdisk is restored.

## Generated Bundle Patch Smoke

Before publishing `dist/rootAVD.sh` as a release artifact, repeat one normal
patch flow from a bundle-only directory:

- Run `tools/build-rootavd-bundle.sh`.
- Copy `dist/rootAVD.sh` into an empty temporary directory as `rootAVD.sh`.
- Add only the runtime inputs needed for the selected smoke, such as
  `Magisk.zip` or `Apps/`, if the flow depends on them.
- Run `./rootAVD.sh <system-image>/ramdisk.img` from that directory.
- Verify the same patch, pullback, reboot, Magisk launch, and restore evidence
  as the source checkout flow.

## Feature-Specific Checks

- `FAKEBOOTIMG`: run `./rootAVD.sh <system-image>/ramdisk.img FAKEBOOTIMG`.
- `PATCHFSTAB`: run `./rootAVD.sh <system-image>/ramdisk.img PATCHFSTAB`.
- `GetUSBHPmodZ`: run `./rootAVD.sh <system-image>/ramdisk.img GetUSBHPmodZ`
  when the AVD has network access.
- `AddRCscripts`: place a known local `.rc` file in the checkout, run
  `./rootAVD.sh <system-image>/ramdisk.img AddRCscripts`, then confirm the rc
  payload is present in the patched ramdisk.
- `InstallApps` with a real APK: place a disposable test APK in `Apps/`, run
  `./rootAVD.sh InstallApps`, then verify the package is installed or the
  expected compatibility fallback ran.
- `InstallKernelModules`: provide local `initramfs.img` and, when replacing the
  kernel, local `bzImage`; run
  `./rootAVD.sh <system-image>/ramdisk.img InstallKernelModules`.
- `InstallPrebuiltKernelModules`: run
  `./rootAVD.sh <system-image>/ramdisk.img InstallPrebuiltKernelModules` with an
  online AVD and verify the downloaded kernel is pulled back.
- `toggleRamdisk`: after creating stock/patched files, run
  `./rootAVD.sh <system-image>/ramdisk.img toggleRamdisk` twice and verify it
  swaps to patched and then back to stock.
- `UpdateBusyBoxScript`: run
  `./rootAVD.sh <system-image>/ramdisk.img UpdateBusyBoxScript` only when
  intentionally refreshing the embedded BusyBox payload.

## Platform-Specific Checks

- `BLUESTACKS`: run `./rootAVD.sh BLUESTACKS` against a real BlueStacks target
  and verify the ramdisk backup, Magisk payload, permissions, and finalization.
- Windows wrapper: run the same source-checkout AVD smoke through
  `rootAVD.bat <system-image>\ramdisk.img` and verify the modular payload is
  copied before the emulator shell invocation.

## Evidence To Record

- Host OS and shell.
- Android SDK path.
- AVD package path and `Pkg.Revision`.
- Architecture and API level.
- Command that was run.
- Whether the source loader or generated bundle was used.
- Magisk version selected.
- Result: patched, restored, skipped, or failed with the first failing line.
