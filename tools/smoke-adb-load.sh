#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

remote_dir=/data/local/tmp/rootavd-smoke

cleanup() {
    adb shell rm -rf "$remote_dir" > /dev/null 2>&1 || true
}

run_step() {
    local label="$1"
    shift

    printf '[*] %s\n' "$label"
    "$@"
}

require_adb_device() {
    if ! command -v adb > /dev/null 2>&1; then
        printf '[!] adb not found in PATH\n' >&2
        return 1
    fi

    if [ "$(adb get-state 2> /dev/null)" != "device" ]; then
        printf '[!] no connected adb device/emulator found\n' >&2
        return 1
    fi
}

prepare_remote_dir() {
    adb shell rm -rf "$remote_dir"
    adb shell mkdir -p "$remote_dir"
}

smoke_source_payload() {
    run_step "Push source loader and modules" adb push rootAVD.sh "$remote_dir/rootAVD.sh"
    run_step "Push source modules" adb push lib/rootavd "$remote_dir/lib/rootavd"
    run_step "Run source payload in Android shell" adb shell sh "$remote_dir/rootAVD.sh" SOURCING DEBUG
}

smoke_bundle_payload() {
    run_step "Build single-file bundle" tools/build-rootavd-bundle.sh
    run_step "Reset remote smoke directory" prepare_remote_dir
    run_step "Push generated bundle" adb push dist/rootAVD.sh "$remote_dir/rootAVD.sh"
    run_step "Run bundled payload in Android shell" adb shell sh "$remote_dir/rootAVD.sh" SOURCING DEBUG
}

main() {
    require_adb_device
    trap cleanup EXIT

    run_step "Prepare remote smoke directory" prepare_remote_dir
    smoke_source_payload
    smoke_bundle_payload

    printf '[*] ADB loader smoke passed\n'
}

main "$@"
