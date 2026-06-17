# Manual Smoke Results - 2026-06-17

## Run Metadata

- Date: 2026-06-17
- Tester: local fork maintainer
- Source checkout or bundle: source checkout
- Host OS and version: macOS
- Host shell: zsh
- Magisk version selected: local stable `30.6`
- `tools/check.sh` result: passed with 165 tests after the follow-up fixes
- `tools/smoke-nondestructive.sh` result: passed as part of `tools/check.sh`

## API 36.1 System Images

| System Image | Architecture | `Pkg.Revision` | Command | Result | Notes |
| --- | --- | --- | --- | --- | --- |
| Google Play Store API 36.1 | `arm64-v8a` | `4` | `./rootAVD.sh system-images/android-36.1/google_apis_playstore/arm64-v8a/ramdisk.img` | Passed source patch flow and restore | Reached ADB emulator flow, preserved modular payload through BusyBox ash re-exec, detected API 36 / Android 16, processed `lz4_legacy` ramdisk, verified matching kernel release, pulled back patched ramdisk and Magisk artifacts, installed `Apps/Magisk.apk` with `Success`, requested AVD shutdown, cold-booted successfully, Magisk launched, `restore` made `ramdisk.img` byte-identical to `ramdisk.img.backup`, and post-restore `su` was unavailable. |
| Google Play Store API 36.1 | `x86_64` |  | `./rootAVD.sh <system-image>/ramdisk.img` | Not run yet | Still required before a compatibility release claim. |
| Generated bundle patch smoke |  |  | `./rootAVD.sh <system-image>/ramdisk.img` from bundle-only directory | Not run yet | Still required before publishing a single-file release artifact. |

## Follow-Up Fixes From This Smoke

- `PrepBusyBoxAndMagisk` now preserves `lib/rootavd` before Magisk extraction cleanup and restores it before the BusyBox ash re-exec can source modules.
- `install_apps` no longer loops indefinitely on non-retryable `adb install` failures; it retries only the `INSTALL_FAILED_UPDATE_INCOMPATIBLE` uninstall/reinstall path.

## Verified After Initial Patch

- Patched API 36.1 `arm64-v8a` AVD booted again after shutdown/cold boot.
- Magisk launched successfully in the patched AVD.
- `restore` restored the original ramdisk:
  - `ramdisk.img` and `ramdisk.img.backup` had matching SHA-256:
    `61871e7a43bcb2c9a8804fd97cd6b4d53c69015397a073b02b439febe9c88934`
  - `cmp -s "$RD" "$RD.backup"` succeeded.
  - `adb shell su` after restore returned `su: inaccessible or not found`.

## Still Required

- Run the API 36.1 Google Play Store `x86_64` patch, reboot, Magisk launch, and restore flow.
- Run the generated bundle patch smoke from a bundle-only directory.
- Run the feature-mode and platform-specific checks listed in `docs/manual-smoke.md`.
