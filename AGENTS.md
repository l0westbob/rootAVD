# AGENTS.md

## Repository Map

| Path | Topic / Responsibility | Inspect When | Ignore Unless |
| --- | --- | --- | --- |
| `rootAVD.sh` | Public Unix/emulator loader. | Entrypoint, sourcing, bundle behavior. | Deep implementation changes. |
| `lib/rootavd/bootstrap.sh` | Runtime setup and module loading. | Loader, module order, shared helpers. | Feature logic. |
| `lib/rootavd/args.sh` | CLI argument contract. | Public flags and positional modes. | Runtime patching. |
| `lib/rootavd/platform.sh` | SDK and system-image discovery. | `ANDROID_HOME`, help examples. | Emulator-only patching. |
| `lib/rootavd/adb.sh` | ADB transport helpers. | Host-to-emulator copy, pull, shutdown. | Magisk internals. |
| `lib/rootavd/backups.sh` | Backup, restore, toggle helpers. | `.backup` and patched ramdisk toggles. | Download logic. |
| `lib/rootavd/apps.sh` | APK installation and app permissions. | `InstallApps`, APK install fallback. | Kernel modules. |
| `lib/rootavd/magisk_downloads.sh` | Magisk/channel/download flow. | Network, menu, download changes. | Ramdisk byte handling. |
| `lib/rootavd/magisk_prepare.sh` | Magisk/BusyBox extraction and preparation. | BusyBox, zip extraction, architecture prep. | Host SDK lookup. |
| `lib/rootavd/ramdisk.sh` | Ramdisk compression, extraction, patching, repack. | Core patch flow, fstab, overlays. | Host ADB setup. |
| `lib/rootavd/ramdisk_fake_boot.sh` | Fake boot image generation and Magisk handoff. | `FAKEBOOTIMG` behavior. | Normal ramdisk repack flow. |
| `lib/rootavd/kernel_modules.sh` | Prebuilt/custom kernel module workflow. | `InstallKernelModules`, prebuilt downloads. | BlueStacks loader text. |
| `lib/rootavd/bluestacks.sh` | BlueStacks host/emulator handling. | `BLUESTACKS` behavior and permissions. | Standard AVD flow. |
| `lib/rootavd/bluestacks_loader_template.sh` | Generated BlueStacks loader strings. | Template output only. | General logic cleanup. |
| `lib/rootavd/help.sh` | Help text. | CLI docs/help examples. | Runtime behavior. |
| `lib/rootavd/main.sh` | High-level orchestration. | Host/emulator flow routing. | Leaf helper internals. |
| `tools/` | Local checks, bundle generation, smoke scripts. | Quality gates and release artifacts. | Runtime behavior. |
| `.github/workflows/check.yml` | GitHub Actions quality gate. | CI/tooling changes. | Runtime behavior. |
| `test/` | Bats regression tests. | Any behavior/refactor change. | Manual-only emulator smoke results. |
| `rootAVD.bat` | Windows wrapper. | Windows support. | Unix-only work. |
| `README.md` | Usage, fork status, contributor workflow. | CLI/fork docs. | Code cleanup. |
| `CompatibilityChart.md` | Support matrix. | API claims. | Most tasks. |
| `docs/manual-smoke.md` | Manual release smoke checklist. | Release validation and compatibility proof. | Pure code cleanup. |
| `docs/manual-smoke-results-template.md` | Manual smoke evidence template. | Recording release validation results. | Pure code cleanup. |
| `docs/refactor-status.md` | Refactor proof matrix. | Automated vs manual proof boundaries. | Pure runtime fixes. |

## Common Task Routing

| Task Type | First Inspection Targets |
| --- | --- |
| Unix/macOS/Linux behavior | `rootAVD.sh`, `lib/rootavd/main.sh`, then owning module. |
| Windows behavior | `rootAVD.bat`, then README Windows examples. |
| ADB or SDK discovery | `lib/rootavd/adb.sh`, `lib/rootavd/platform.sh`. |
| Magisk downloads | `lib/rootavd/magisk_downloads.sh`. |
| Magisk or BusyBox prep | `lib/rootavd/magisk_prepare.sh`. |
| Ramdisk patching | `lib/rootavd/ramdisk.sh`, `lib/rootavd/ramdisk_fake_boot.sh`, focused Bats fixtures. |
| Kernel modules | `lib/rootavd/kernel_modules.sh`, HTML fixture tests. |
| BlueStacks | `lib/rootavd/bluestacks.sh`, then `lib/rootavd/bluestacks_loader_template.sh`. |
| CLI/help/docs changes | `lib/rootavd/args.sh`, `lib/rootavd/help.sh`, `README.md`. |
| Bundling/release script | `tools/build-rootavd-bundle.sh`, `tools/smoke-nondestructive.sh`, `tools/smoke-adb-load.sh`, `test/rootavd_bundle.bats`. |
| Quality/tooling changes | `tools/check.sh`, `.github/workflows/check.yml`, `test/`, small config files. |
| Release/manual smoke proof | `docs/refactor-status.md`, `docs/manual-smoke.md`, `docs/manual-smoke-results-template.md`, `README.md`, `CompatibilityChart.md`. |

## Context Budget Rules

- Start with the module or doc section that owns the requested behavior.
- Use `rg` for functions, flags, labels, and command names before broad file reads.
- Read `rootAVD.sh`, `bootstrap.sh`, and `main.sh` for flow, then jump to leaf modules.
- Inspect nearby Bats tests before broadening to the full suite.
- Avoid generated files, runtime artifacts, IDE metadata, backups, APKs, and archives by default.
- Summarize what you learned before opening more unrelated files.

## Important Entry Points

| File | Why It Matters |
| --- | --- |
| `rootAVD.sh` | Primary executable loader. |
| `lib/rootavd/main.sh` | Host/emulator orchestration and compatibility wrappers. |
| `tools/check.sh` | Local size, syntax, ShellCheck style, shfmt, whitespace, bundle, and Bats gate. |
| `.github/workflows/check.yml` | CI entry point that runs `tools/check.sh`. |
| `tools/build-rootavd-bundle.sh` | Single-file release artifact generator. |
| `tools/smoke-nondestructive.sh` | Local source/bundle smoke runner that avoids patching AVD files. |
| `tools/smoke-adb-load.sh` | Optional live ADB source/bundle loader smoke that avoids patching AVD files. |
| `rootAVD.bat` | Windows entry point and ADB wrapper. |
| `README.md` | Public installation, usage, and fork status contract. |
| `docs/manual-smoke.md` | Manual release validation checklist. |
| `docs/manual-smoke-results-template.md` | Template for release validation results. |
| `docs/refactor-status.md` | Current refactor proof and release-readiness matrix. |

## Do Not Touch / Ignore By Default

- `.git/`, `.idea/`, `.DS_Store`
- `Magisk.zip` unless intentionally updating the bundled Magisk artifact.
- `Apps/*` except `Apps/.gitkeep`; APKs are user/runtime input.
- Generated/runtime files: `tmp/`, `assets/`, `busybox`, `dist/`.
- Runtime outputs: `Magisk.apk`, `ramdiskpatched4AVD.img`, `*.backup`, `*.patched`.
- Kernel/module inputs: `initramfs.img`, `bzImage`, `*.rc`, `libbusybox*`, `sbin*`.
- Large README archive blocks unless CLI docs are changing.
- Do not invent a dependency manifest for small script edits.

## Agent Workflow

1. Classify the task.
2. Inspect only relevant folders/files first.
3. Inspect nearby tests.
4. Make minimal changes.
5. Run targeted checks.
6. Keep ordinary modules in `lib/rootavd/` free of `shellcheck disable` comments; only `lib/rootavd/bluestacks_loader_template.sh` may carry generated-template suppressions.
7. Run `tools/check.sh` before handoff when code, tests, tooling, or shell docs change.
8. Broaden context only if needed.
