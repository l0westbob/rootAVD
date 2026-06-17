#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

source_output=""
bundle_output=""
smoke_sdk=""

cleanup() {
    [ -z "$source_output" ] || rm -f "$source_output"
    [ -z "$bundle_output" ] || rm -f "$bundle_output"
    [ -z "$smoke_sdk" ] || rm -rf "$smoke_sdk"
}

run_step() {
    local label="$1"
    shift

    printf '[*] %s\n' "$label"
    "$@"
}

run_capture_step() {
    local label="$1"
    local output_file="$2"
    shift 2

    printf '[*] %s\n' "$label"
    "$@" > "$output_file"
}

compare_smoke_outputs() {
    local source_output="$1"
    local bundle_output="$2"

    printf '[*] Compare source and bundle ListAllAVDs output\n'
    if ! diff -u "$source_output" "$bundle_output"; then
        printf '[!] Source and bundle ListAllAVDs output differ\n' >&2
        return 1
    fi
}

create_smoke_ramdisk() {
    local sdk="$1"
    local ramdisk_rel="$2"
    local ramdisk="$sdk/$ramdisk_rel"

    mkdir -p "${ramdisk%/*}"
    printf '%s\n' "patched" > "$ramdisk"
    printf '%s\n' "stock" > "$ramdisk.backup"
    rm -f "$ramdisk.patched"
}

run_public_file_mode_smoke() {
    local label="$1"
    local executable="$2"
    local mode="$3"
    local ramdisk_rel="system-images/android-36.1/google_apis_playstore/x86_64/ramdisk.img"
    local ramdisk="$smoke_sdk/$ramdisk_rel"

    create_smoke_ramdisk "$smoke_sdk" "$ramdisk_rel"
    run_step "$label $mode" env ANDROID_HOME="$smoke_sdk" "$executable" "$ramdisk_rel" "$mode"

    case "$mode" in
        restore)
            if [ "$(cat "$ramdisk")" != "stock" ]; then
                printf '[!] %s restore did not restore stock ramdisk\n' "$label" >&2
                return 1
            fi
            ;;
        toggleRamdisk)
            if [ "$(cat "$ramdisk")" != "stock" ] || [ "$(cat "$ramdisk.patched")" != "patched" ]; then
                printf '[!] %s toggleRamdisk did not swap stock and patched ramdisks\n' "$label" >&2
                return 1
            fi
            ;;
    esac
}

main() {
    trap cleanup EXIT
    export TERM="${TERM:-dumb}"

    source_output=$(mktemp)
    bundle_output=$(mktemp)
    smoke_sdk=$(mktemp -d)

    run_step "Build single-file bundle" tools/build-rootavd-bundle.sh
    run_step "Parse source loader with sh" sh -n rootAVD.sh
    run_step "Parse generated bundle with sh" sh -n dist/rootAVD.sh
    run_capture_step "Run source ListAllAVDs" "$source_output" ./rootAVD.sh ListAllAVDs
    run_capture_step "Run bundle ListAllAVDs" "$bundle_output" dist/rootAVD.sh ListAllAVDs
    compare_smoke_outputs "$source_output" "$bundle_output"
    run_public_file_mode_smoke "Run source" ./rootAVD.sh restore
    run_public_file_mode_smoke "Run source" ./rootAVD.sh toggleRamdisk
    run_public_file_mode_smoke "Run bundle" dist/rootAVD.sh restore
    run_public_file_mode_smoke "Run bundle" dist/rootAVD.sh toggleRamdisk

    printf '[*] Non-destructive smoke passed\n'
}

main "$@"
