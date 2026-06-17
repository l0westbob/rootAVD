#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "create_backup creates one backup and does not overwrite it" {
  work="$BATS_TEST_TMPDIR/work"
  mkdir -p "$work"
  printf "original\n" > "$work/ramdisk.img"

  run bash -c 'SOURCING=true source "$1"; create_backup "$2/ramdisk.img"; printf "changed\n" > "$2/ramdisk.img"; create_backup "$2/ramdisk.img"; cat "$2/ramdisk.img.backup"' _ "$REPO_ROOT/rootAVD.sh" "$work"

  [ "$status" -eq 0 ]
  [[ "$output" == *"original"* ]]
  [[ "$output" != *"changed"* ]]
}

@test "restore_backups restores backup files" {
  work="$BATS_TEST_TMPDIR/work"
  mkdir -p "$work"
  printf "backup\n" > "$work/ramdisk.img.backup"
  printf "current\n" > "$work/ramdisk.img"

  run bash -c 'SOURCING=true source "$1"; restore_backups "$2"; cat "$2/ramdisk.img"' _ "$REPO_ROOT/rootAVD.sh" "$work"

  [ "$status" -eq 0 ]
  [[ "$output" == *"backup"* ]]
}

@test "toggle_Ramdisk stores patched file on first toggle" {
  work="$BATS_TEST_TMPDIR/work"
  mkdir -p "$work"
  printf "stock\n" > "$work/ramdisk.img.backup"
  printf "patched\n" > "$work/ramdisk.img"

  run bash -c 'SOURCING=true source "$1"; AVDPATHWITHRDFFILE="$2/ramdisk.img"; toggle_Ramdisk "$2"' _ "$REPO_ROOT/rootAVD.sh" "$work"

  [ "$status" -eq 0 ]
  [ "$(cat "$work/ramdisk.img")" = "stock" ]
  [ "$(cat "$work/ramdisk.img.patched")" = "patched" ]
}

@test "toggle_Ramdisk restores patched file on second toggle" {
  work="$BATS_TEST_TMPDIR/work"
  mkdir -p "$work"
  printf "stock\n" > "$work/ramdisk.img.backup"
  printf "stock\n" > "$work/ramdisk.img"
  printf "patched\n" > "$work/ramdisk.img.patched"

  run bash -c 'SOURCING=true source "$1"; AVDPATHWITHRDFFILE="$2/ramdisk.img"; toggle_Ramdisk "$2"' _ "$REPO_ROOT/rootAVD.sh" "$work"

  [ "$status" -eq 0 ]
  [ "$(cat "$work/ramdisk.img")" = "patched" ]
}

@test "public restore mode restores backups without entering ADB flow" {
  sdk="$BATS_TEST_TMPDIR/sdk restore"
  ramdisk_rel="system-images/android-36/google_apis_playstore/x86_64/ramdisk.img"
  ramdisk="$sdk/$ramdisk_rel"
  mkdir -p "${ramdisk%/*}"
  printf '%s\n' "modified" > "$ramdisk"
  printf '%s\n' "stock" > "$ramdisk.backup"

  run bash -c '
    ANDROID_HOME="$2"
    source "$1" SOURCING >/dev/null
    SOURCING=false
    getprop() { return 1; }
    TestADB() { echo UNEXPECTED_ADB_FLOW; return 33; }
    rootavd_main "$3" restore
    cat "$2/$3"
  ' _ "$REPO_ROOT/rootAVD.sh" "$sdk" "$ramdisk_rel"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Restoring ramdisk.img.backup to ramdisk.img"* ]]
  [ "$(cat "$ramdisk")" = "stock" ]
  [[ "$output" != *"UNEXPECTED_ADB_FLOW"* ]]
}

@test "public toggleRamdisk mode toggles files without entering ADB flow" {
  sdk="$BATS_TEST_TMPDIR/sdk toggle"
  ramdisk_rel="system-images/android-36/google_apis_playstore/x86_64/ramdisk.img"
  ramdisk="$sdk/$ramdisk_rel"
  mkdir -p "${ramdisk%/*}"
  printf '%s\n' "patched" > "$ramdisk"
  printf '%s\n' "stock" > "$ramdisk.backup"

  run bash -c '
    ANDROID_HOME="$2"
    source "$1" SOURCING >/dev/null
    SOURCING=false
    getprop() { return 1; }
    TestADB() { echo UNEXPECTED_ADB_FLOW; return 33; }
    rootavd_main "$3" toggleRamdisk
    cat "$2/$3"
    cat "$2/$3.patched"
  ' _ "$REPO_ROOT/rootAVD.sh" "$sdk" "$ramdisk_rel"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Toggle Ramdisk"* ]]
  [ "$(cat "$ramdisk")" = "stock" ]
  [ "$(cat "$ramdisk.patched")" = "patched" ]
  [[ "$output" != *"UNEXPECTED_ADB_FLOW"* ]]
}
