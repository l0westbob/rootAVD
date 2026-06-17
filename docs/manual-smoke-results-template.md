# Manual Smoke Results

Copy this template when validating a release candidate. Keep one completed copy
with the release notes, pull request, or tag evidence.

## Run Metadata

- Date:
- Tester:
- Commit:
- Source checkout or bundle:
- Host OS and version:
- Host shell:
- Android SDK path:
- `ANDROID_HOME`:
- ADB version:
- Magisk version selected:
- `tools/check.sh` result:
- `tools/smoke-nondestructive.sh` result:

## Source And Bundle Loading

| Check | Command | Result | Notes |
| --- | --- | --- | --- |
| Source `ListAllAVDs` | `./rootAVD.sh ListAllAVDs` |  |  |
| Bundle `ListAllAVDs` | `dist/rootAVD.sh ListAllAVDs` |  |  |
| Source Android shell load | `sh rootAVD.sh SOURCING DEBUG` |  |  |
| Bundle Android shell load | `sh rootAVD.sh SOURCING DEBUG` |  |  |
| Empty `InstallApps` | `./rootAVD.sh InstallApps` |  | Confirm `Apps/.gitkeep` was ignored. |

## API 36.1 System Images

| System Image | Architecture | `Pkg.Revision` | Command | Result | Notes |
| --- | --- | --- | --- | --- | --- |
| Google Play Store API 36.1 | `arm64-v8a` |  | `./rootAVD.sh <system-image>/ramdisk.img` |  |  |
| Google Play Store API 36.1 | `x86_64` |  | `./rootAVD.sh <system-image>/ramdisk.img` |  |  |
| Generated bundle patch smoke |  |  | `./rootAVD.sh <system-image>/ramdisk.img` from bundle-only directory |  |  |

For each row above, record whether:

- The script reached the emulator flow through ADB.
- Magisk and BusyBox preparation completed.
- The patched ramdisk was pulled back to the host.
- The AVD booted again after patching.
- Magisk launched successfully.
- `restore` restored the original ramdisk.

## Feature Modes

| Mode | Command | Target | Result | Notes |
| --- | --- | --- | --- | --- |
| `FAKEBOOTIMG` | `./rootAVD.sh <system-image>/ramdisk.img FAKEBOOTIMG` |  |  |  |
| `PATCHFSTAB` | `./rootAVD.sh <system-image>/ramdisk.img PATCHFSTAB` |  |  |  |
| `GetUSBHPmodZ` | `./rootAVD.sh <system-image>/ramdisk.img GetUSBHPmodZ` |  |  |  |
| `AddRCscripts` | `./rootAVD.sh <system-image>/ramdisk.img AddRCscripts` |  |  |  |
| `InstallApps` | `./rootAVD.sh InstallApps` |  |  |  |
| `InstallKernelModules` | `./rootAVD.sh <system-image>/ramdisk.img InstallKernelModules` |  |  |  |
| `InstallPrebuiltKernelModules` | `./rootAVD.sh <system-image>/ramdisk.img InstallPrebuiltKernelModules` |  |  |  |
| `toggleRamdisk` | `./rootAVD.sh <system-image>/ramdisk.img toggleRamdisk` |  |  |  |
| `UpdateBusyBoxScript` | `./rootAVD.sh <system-image>/ramdisk.img UpdateBusyBoxScript` |  |  |  |

## Platform-Specific Checks

| Platform | Command | Result | Notes |
| --- | --- | --- | --- |
| `BLUESTACKS` | `./rootAVD.sh BLUESTACKS` |  |  |
| Windows wrapper | `rootAVD.bat <system-image>\ramdisk.img` |  |  |

## Failures Or Deviations

- First failing line:
- Log excerpt:
- Recovery performed:
- Follow-up issue or commit:
