#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "public argument surface matches legacy command words" {
  current="$BATS_TEST_TMPDIR/current-public-arguments.txt"

  sed -n \
    -e 's/.*has_argument "\([^"]*\)".*/\1/p' \
    -e 's/^[[:space:]]*"\([^"]*\)")[[:space:]]*$/\1/p' \
    "$REPO_ROOT/lib/rootavd/args.sh" | sort -u > "$current"

  run diff -u "$REPO_ROOT/test/fixtures/rootavd_public_arguments.expected" "$current"

  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "public argument surface is documented in user-facing markdown" {
  run bash -c '
    repo_root="$1"
    missing=0
    docs="$repo_root/README.md $repo_root/docs/manual-smoke.md $repo_root/docs/manual-smoke-results-template.md"

    while IFS= read -r argument; do
      [ -n "$argument" ] || continue
      if ! grep -F -- "$argument" $docs > /dev/null; then
        printf "missing documented public argument: %s\n" "$argument"
        missing=1
      fi
    done < "$repo_root/test/fixtures/rootavd_public_arguments.expected"

    exit "$missing"
  ' _ "$REPO_ROOT"

  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "exact DEBUG argument enables debug mode" {
  run bash -c 'source "$1" SOURCING DEBUG; printf "%s\n" "$DEBUG"' _ "$REPO_ROOT/rootAVD.sh"

  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "path containing DEBUG does not enable debug mode" {
  run bash -c 'SOURCING=true source "$1" "system-images/android-36/google_apis_playstore/x86_64/ramdisk.DEBUG.img"; printf "%s\n" "$DEBUG"' _ "$REPO_ROOT/rootAVD.sh"

  [ "$status" -eq 0 ]
  [ "$output" = "false" ]
}

@test "SOURCING argument prevents normal execution" {
  run bash -c 'source "$1" SOURCING; printf "%s\n" "$SOURCING"' _ "$REPO_ROOT/rootAVD.sh"

  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "argument parsing is safe when sourced from nounset shells" {
  run bash -u -c 'source "$1" SOURCING; printf "%s %s\n" "$SOURCING" "$restore"' _ "$REPO_ROOT/rootAVD.sh"

  [ "$status" -eq 0 ]
  [ "$output" = "true false" ]
}

@test "BLUESTACKS disables ramdisk image mode" {
  run bash -c 'source "$1" SOURCING BLUESTACKS; printf "%s %s\n" "$BLUESTACKS" "$RAMDISKIMG"' _ "$REPO_ROOT/rootAVD.sh"

  [ "$status" -eq 0 ]
  [ "$output" = "true false" ]
}

@test "second positional restore mode is parsed" {
  run bash -c 'SOURCING=true source "$1" "system-images/android-36/google_apis_playstore/x86_64/ramdisk.img" restore; printf "%s\n" "$restore"' _ "$REPO_ROOT/rootAVD.sh"

  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "second positional kernel module modes are parsed" {
  run bash -c 'SOURCING=true source "$1" "system-images/android-36/google_apis_playstore/x86_64/ramdisk.img" InstallKernelModules; printf "%s\n" "$InstallKernelModules"' _ "$REPO_ROOT/rootAVD.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]

  run bash -c 'SOURCING=true source "$1" "system-images/android-36/google_apis_playstore/x86_64/ramdisk.img" InstallPrebuiltKernelModules; printf "%s\n" "$InstallPrebuiltKernelModules"' _ "$REPO_ROOT/rootAVD.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "all public flag arguments are parsed" {
  run bash -c '
    SOURCING=true source "$1" \
      "system-images/android-36/google_apis_playstore/x86_64/ramdisk.img" \
      PATCHFSTAB GetUSBHPmodZ ListAllAVDs InstallApps UpdateBusyBoxScript \
      AddRCscripts toggleRamdisk FAKEBOOTIMG
    printf "%s\n" \
      "$PATCHFSTAB" \
      "$GetUSBHPmodZ" \
      "$ListAllAVDs" \
      "$InstallApps" \
      "$UpdateBusyBoxScript" \
      "$AddRCscripts" \
      "$toggleRamdisk" \
      "$FAKEBOOTIMG" \
      "$RAMDISKIMG"
  ' _ "$REPO_ROOT/rootAVD.sh"

  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "true" ]
  [ "${lines[1]}" = "true" ]
  [ "${lines[2]}" = "true" ]
  [ "${lines[3]}" = "true" ]
  [ "${lines[4]}" = "true" ]
  [ "${lines[5]}" = "true" ]
  [ "${lines[6]}" = "true" ]
  [ "${lines[7]}" = "true" ]
  [ "${lines[8]}" = "true" ]
}
