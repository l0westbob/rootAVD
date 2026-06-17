# Refactor Status

This file tracks the modular Bash rewrite against the original refactor goal.
It separates what the automated suite proves from what still requires a real
host, emulator, or platform-specific smoke test.

## Automated Proof

| Requirement | Evidence |
| --- | --- |
| `rootAVD.sh` remains the public entrypoint. | `test/rootavd_bundle.bats` checks `rootavd_main "$@"` is called only from `rootAVD.sh`. |
| Implementation is split by responsibility under `lib/rootavd/`. | `test/rootavd_modules.bats` checks the planned module list and source order. |
| Public CLI words stay unchanged. | `test/rootavd_args.bats` checks the public argument fixture and documentation coverage. |
| Legacy function names are still available during migration. | `test/rootavd_function_surface.bats` checks source and bundle function surfaces. |
| Source mode pushes modules to the emulator. | `test/rootavd_adb_mock.bats` checks modular payload push commands. |
| Bundle mode can run without source modules. | `test/rootavd_bundle.bats` checks the generated bundle is self-contained. |
| Windows wrapper still pushes modular payloads. | `test/rootavd_windows_wrapper.bats` checks `rootAVD.bat` source payload commands. |
| Help output remains stable across source and bundle modes. | `test/rootavd_help.bats` compares public help text. |
| Entrypoint, modules, and tools stay maintainable in size. | `tools/check.sh` and `test/rootavd_size.bats` enforce line budgets. |
| Public shell entrypoints and tools stay directly runnable. | `test/rootavd_repo_hygiene.bats` checks executable bits for `rootAVD.sh` and the scripts under `tools/`. |
| Shell syntax, ShellCheck, formatting, bundle, smoke, and Bats stay green. | `tools/check.sh` runs the local gate and is mirrored by `.github/workflows/check.yml`. |
| ShellCheck stays clean at style severity. | `tools/check.sh` runs `shellcheck --severity=style` for entrypoints, tools, modules, and Bats tests; `test/rootavd_ci.bats` pins that threshold. |
| Ordinary modules stay free of ShellCheck suppressions. | `test/rootavd_repo_hygiene.bats` allows suppressions only in the isolated BlueStacks loader template and source-loading annotations outside ordinary modules. |
| Non-destructive source/bundle runtime behavior matches. | `tools/smoke-nondestructive.sh` compares `ListAllAVDs` and checks `restore` and `toggleRamdisk` against a temporary SDK tree. |
| Empty `InstallApps` does not install placeholders. | `test/rootavd_apps.bats` checks non-APK files such as `Apps/.gitkeep` are ignored; `./rootAVD.sh InstallApps` is safe as a no-APK ADB smoke. |

## Manually Proven Before Release

Record these results with
[docs/manual-smoke-results-template.md](manual-smoke-results-template.md).
Current in-progress evidence is recorded in
[docs/manual-smoke-results-2026-06-17.md](manual-smoke-results-2026-06-17.md).

| Workflow | Required Evidence |
| --- | --- |
| API 36.1 Google Play Store `arm64-v8a`. | Real patch, reboot, Magisk launch, and restore. |
| API 36.1 Google Play Store `x86_64`. | Real patch, reboot, Magisk launch, and restore. |
| Generated bundle release artifact. | Real patch from a bundle-only directory, followed by reboot, Magisk launch, and restore. |
| `FAKEBOOTIMG`. | Generated fake boot image patches through Magisk and extracts back into ramdisk flow. |
| `PATCHFSTAB`. | Patched ramdisk contains the expected fstab overlay changes. |
| `GetUSBHPmodZ`. | Online AVD downloads and stages the USB host permissions payload. |
| `AddRCscripts`. | A known `.rc` payload appears in the patched ramdisk. |
| `InstallApps` with a real APK. | Disposable APK installs or follows the expected compatibility fallback. |
| `InstallKernelModules`. | Local modules and optional local kernel are applied and pulled back. |
| `InstallPrebuiltKernelModules`. | Online prebuilt kernel/module download and replacement succeeds. |
| `UpdateBusyBoxScript`. | Embedded BusyBox refresh is intentionally run and reviewed. |
| `BLUESTACKS`. | Real BlueStacks target backs up, patches, sets permissions, and finalizes correctly. |
| `rootAVD.bat`. | Windows wrapper executes the same source-checkout flow with modular payloads. |

## Current Release Readiness

The repository is ready for non-destructive automated review when `tools/check.sh`
passes. It is not ready for a compatibility release claim until the manual
matrix above has fresh results for the target platforms.
