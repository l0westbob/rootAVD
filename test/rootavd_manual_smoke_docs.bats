#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "manual smoke checklist covers release validation surface" {
    run bash -c '
    doc="$1/docs/manual-smoke.md"
    missing=0

    while IFS= read -r required_text; do
      [ -n "$required_text" ] || continue
      if ! grep -F -- "$required_text" "$doc" > /dev/null; then
        printf "missing manual smoke text: %s\n" "$required_text"
        missing=1
      fi
    done << REQUIRED_SMOKE_TEXT
./rootAVD.sh ListAllAVDs
tools/build-rootavd-bundle.sh
tools/smoke-nondestructive.sh
tools/smoke-adb-load.sh
dist/rootAVD.sh ListAllAVDs
sh rootAVD.sh SOURCING DEBUG
Generated Bundle Patch Smoke
bundle-only directory
./rootAVD.sh InstallApps
Apps/.gitkeep
FAKEBOOTIMG
PATCHFSTAB
GetUSBHPmodZ
AddRCscripts
InstallKernelModules
InstallPrebuiltKernelModules
toggleRamdisk
UpdateBusyBoxScript
BLUESTACKS
rootAVD.bat
Pkg.Revision
REQUIRED_SMOKE_TEXT

    exit "$missing"
  ' _ "$REPO_ROOT"

    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "manual smoke results template covers release validation surface" {
    run bash -c '
    doc="$1/docs/manual-smoke-results-template.md"
    missing=0

    while IFS= read -r required_text; do
      [ -n "$required_text" ] || continue
      if ! grep -F -- "$required_text" "$doc" > /dev/null; then
        printf "missing manual smoke template text: %s\n" "$required_text"
        missing=1
      fi
    done << REQUIRED_TEMPLATE_TEXT
tools/check.sh
tools/smoke-nondestructive.sh
./rootAVD.sh ListAllAVDs
dist/rootAVD.sh ListAllAVDs
sh rootAVD.sh SOURCING DEBUG
./rootAVD.sh InstallApps
Apps/.gitkeep
Google Play Store API 36.1
arm64-v8a
x86_64
Pkg.Revision
Generated bundle patch smoke
bundle-only directory
FAKEBOOTIMG
PATCHFSTAB
GetUSBHPmodZ
AddRCscripts
InstallKernelModules
InstallPrebuiltKernelModules
toggleRamdisk
UpdateBusyBoxScript
BLUESTACKS
rootAVD.bat
REQUIRED_TEMPLATE_TEXT

    exit "$missing"
  ' _ "$REPO_ROOT"

    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "refactor status documents automatic and manual proof boundaries" {
    run bash -c '
    doc="$1/docs/refactor-status.md"
    missing=0

    while IFS= read -r required_text; do
      [ -n "$required_text" ] || continue
      if ! grep -F -- "$required_text" "$doc" > /dev/null; then
        printf "missing refactor status text: %s\n" "$required_text"
        missing=1
      fi
    done << REQUIRED_STATUS_TEXT
## Automated Proof
## Manually Proven Before Release
rootAVD.sh
lib/rootavd/
tools/check.sh
Public shell entrypoints and tools stay directly runnable.
Ordinary modules stay free of ShellCheck suppressions.
tools/smoke-nondestructive.sh
API 36.1 Google Play Store
arm64-v8a
x86_64
Generated bundle
bundle-only
FAKEBOOTIMG
PATCHFSTAB
InstallApps
Apps/.gitkeep
InstallKernelModules
InstallPrebuiltKernelModules
BLUESTACKS
rootAVD.bat
REQUIRED_STATUS_TEXT

    exit "$missing"
  ' _ "$REPO_ROOT"

    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "README and AGENTS point at manual smoke docs and refactor status" {
    run grep -F '[docs/manual-smoke.md](docs/manual-smoke.md)' "$REPO_ROOT/README.md"

    [ "$status" -eq 0 ]

    run grep -F '[docs/manual-smoke-results-template.md](docs/manual-smoke-results-template.md)' "$REPO_ROOT/README.md"

    [ "$status" -eq 0 ]

    run grep -F 'docs/manual-smoke.md' "$REPO_ROOT/AGENTS.md"

    [ "$status" -eq 0 ]

    run grep -F 'docs/manual-smoke-results-template.md' "$REPO_ROOT/AGENTS.md"

    [ "$status" -eq 0 ]

    run grep -F '[docs/refactor-status.md](docs/refactor-status.md)' "$REPO_ROOT/README.md"

    [ "$status" -eq 0 ]

    run grep -F 'docs/refactor-status.md' "$REPO_ROOT/AGENTS.md"

    [ "$status" -eq 0 ]

    run grep -F 'generated-template suppressions' "$REPO_ROOT/AGENTS.md"

    [ "$status" -eq 0 ]

    run grep -F 'generated-template suppressions' "$REPO_ROOT/README.md"

    [ "$status" -eq 0 ]
}

@test "current manual smoke evidence is linked from refactor status" {
    run grep -F '[docs/manual-smoke-results-2026-06-17.md](manual-smoke-results-2026-06-17.md)' "$REPO_ROOT/docs/refactor-status.md"

    [ "$status" -eq 0 ]

    run grep -F 'Google Play Store API 36.1' "$REPO_ROOT/docs/manual-smoke-results-2026-06-17.md"

    [ "$status" -eq 0 ]

    run grep -F 'arm64-v8a' "$REPO_ROOT/docs/manual-smoke-results-2026-06-17.md"

    [ "$status" -eq 0 ]
}
