#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "source and bundle help output match for public text" {
  "$REPO_ROOT/tools/build-rootavd-bundle.sh" >/dev/null

  run bash -c '
    export TERM=dumb
    SOURCING=true source "$1"
    FindSystemImages() {
      printf "%s\n" "Command Examples:"
      printf "%s\n" "./rootAVD.sh"
      printf "%s\n" "./rootAVD.sh ListAllAVDs"
      printf "%s\n" "./rootAVD.sh InstallApps"
    }
    defaultHOME_M="~/Library/Android/sdk"
    defaultHOME_L="~/Android/Sdk"
    defaultHOME="~/Library/Android/sdk"
    ShowHelpText
  ' _ "$REPO_ROOT/rootAVD.sh"

  [ "$status" -eq 0 ]
  source_help="$output"
  [ "$source_help" = "$(cat "$REPO_ROOT/test/fixtures/help.expected")" ]

  run bash -c '
    export TERM=dumb
    SOURCING=true source "$1"
    FindSystemImages() {
      printf "%s\n" "Command Examples:"
      printf "%s\n" "./rootAVD.sh"
      printf "%s\n" "./rootAVD.sh ListAllAVDs"
      printf "%s\n" "./rootAVD.sh InstallApps"
    }
    defaultHOME_M="~/Library/Android/sdk"
    defaultHOME_L="~/Android/Sdk"
    defaultHOME="~/Library/Android/sdk"
    ShowHelpText
  ' _ "$REPO_ROOT/dist/rootAVD.sh"

  [ "$status" -eq 0 ]
  [ "$output" = "$source_help" ]
  [[ "$output" == *"ListAllAVDs"* ]]
  [[ "$output" == *"InstallApps"* ]]
  [[ "$output" == *"InstallKernelModules"* ]]
  [[ "$output" == *"InstallPrebuiltKernelModules"* ]]
  [[ "$output" == *"AddRCscripts"* ]]
  [[ "$output" == *"PATCHFSTAB"* ]]
  [[ "$output" == *"GetUSBHPmodZ"* ]]
  [[ "$output" == *"FAKEBOOTIMG"* ]]
}

@test "no arguments shows help without entering ADB flow" {
  sdk="$BATS_TEST_TMPDIR/sdk no args"
  mkdir -p "$sdk/system-images"

  run bash -c '
    export TERM=dumb
    ANDROID_HOME="$2"
    source "$1" SOURCING >/dev/null
    SOURCING=false
    getprop() { return 1; }
    CopyMagiskToAVD() { echo UNEXPECTED_ADB_FLOW; return 33; }
    rootavd_main
  ' _ "$REPO_ROOT/rootAVD.sh" "$sdk"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"Command Examples:"* ]]
  [[ "$output" != *"UNEXPECTED_ADB_FLOW"* ]]
}

@test "missing ramdisk path shows help without entering ADB flow" {
  sdk="$BATS_TEST_TMPDIR/sdk missing ramdisk"
  mkdir -p "$sdk/system-images"

  run bash -c '
    export TERM=dumb
    ANDROID_HOME="$2"
    source "$1" SOURCING >/dev/null
    SOURCING=false
    getprop() { return 1; }
    CopyMagiskToAVD() { echo UNEXPECTED_ADB_FLOW; return 33; }
    rootavd_main "system-images/android-36/google_apis_playstore/x86_64/ramdisk.img"
  ' _ "$REPO_ROOT/rootAVD.sh" "$sdk"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"Command Examples:"* ]]
  [[ "$output" != *"UNEXPECTED_ADB_FLOW"* ]]
}
