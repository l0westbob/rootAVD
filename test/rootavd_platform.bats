#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "GetANDROIDHOME honors ANDROID_HOME and detects system-images" {
  sdk="$BATS_TEST_TMPDIR/sdk"
  mkdir -p "$sdk/system-images"

  run bash -c '
    ANDROID_HOME="$2"
    SOURCING=true source "$1" SOURCING
    GetANDROIDHOME
    printf "%s|%s|%s|%s\n" "$ANDROIDHOME" "$ENVVAR" "$NoSystemImages" "$ADB_DIR"
  ' _ "$REPO_ROOT/rootAVD.sh" "$sdk"

  [ "$status" -eq 0 ]
  [ "$output" = "$sdk|\$ANDROID_HOME|false|platform-tools" ]
}

@test "FindSystemImages prints command examples for discovered ramdisks" {
  sdk="$BATS_TEST_TMPDIR/sdk"
  ramdisk_rel="system-images/android-36/google_apis_playstore/x86_64/ramdisk.img"
  mkdir -p "$sdk/${ramdisk_rel%/*}"
  printf '%s\n' "ramdisk" > "$sdk/$ramdisk_rel"

  run bash -c '
    ANDROID_HOME="$2"
    SOURCING=true source "$1" SOURCING
    bold=""
    normal=""
    ListAllAVDs=false
    GetANDROIDHOME
    FindSystemImages
  ' _ "$REPO_ROOT/rootAVD.sh" "$sdk"

  [ "$status" -eq 0 ]
  [[ "$output" == *"./rootAVD.sh $ramdisk_rel"* ]]
  [[ "$output" == *"./rootAVD.sh $ramdisk_rel FAKEBOOTIMG"* ]]
  [[ "$output" == *"./rootAVD.sh $ramdisk_rel InstallPrebuiltKernelModules"* ]]
}

@test "ListAllAVDs prints examples without entering ADB flow" {
  sdk="$BATS_TEST_TMPDIR/sdk"
  ramdisk_rel="system-images/android-36/google_apis_playstore/x86_64/ramdisk.img"
  mkdir -p "$sdk/${ramdisk_rel%/*}"
  printf '%s\n' "ramdisk" > "$sdk/$ramdisk_rel"

  run bash -c '
    ANDROID_HOME="$2"
    source "$1" SOURCING >/dev/null
    SOURCING=false
    getprop() { return 1; }
    CopyMagiskToAVD() { echo UNEXPECTED_ADB_FLOW; return 33; }
    rootavd_main ListAllAVDs
  ' _ "$REPO_ROOT/rootAVD.sh" "$sdk"

  [ "$status" -eq 0 ]
  [[ "$output" == *"./rootAVD.sh $ramdisk_rel"* ]]
  [[ "$output" != *"UNEXPECTED_ADB_FLOW"* ]]
}

@test "GetAVDPKGRevision reports source.properties revision" {
  avd_path="$BATS_TEST_TMPDIR/system image"
  mkdir -p "$avd_path"
  printf '%s\n' "Pkg.Revision=36.1" > "$avd_path/source.properties"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    AVDPATH="$2"
    GetAVDPKGRevision
  ' _ "$REPO_ROOT/rootAVD.sh" "$avd_path"

  [ "$status" -eq 0 ]
  [[ "$output" == *"source.properties file exist"* ]]
  [[ "$output" == *"Pkg.Revision=36.1"* ]]
}
