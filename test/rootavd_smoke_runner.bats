#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "non-destructive smoke runner verifies source and bundle ListAllAVDs" {
  sdk="$BATS_TEST_TMPDIR/sdk"
  avd_rel="system-images/android-36.1/google_apis_playstore/x86_64/ramdisk.img"
  mkdir -p "$sdk/${avd_rel%/*}"
  printf '%s\n' "stock ramdisk" > "$sdk/$avd_rel"

  run env ANDROID_HOME="$sdk" TERM=dumb "$REPO_ROOT/tools/smoke-nondestructive.sh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Build single-file bundle"* ]]
  [[ "$output" == *"Run source ListAllAVDs"* ]]
  [[ "$output" == *"Run bundle ListAllAVDs"* ]]
  [[ "$output" == *"Compare source and bundle ListAllAVDs output"* ]]
  [[ "$output" == *"Run source restore"* ]]
  [[ "$output" == *"Run source toggleRamdisk"* ]]
  [[ "$output" == *"Run bundle restore"* ]]
  [[ "$output" == *"Run bundle toggleRamdisk"* ]]
  [[ "$output" == *"Non-destructive smoke passed"* ]]
}

@test "full local check gate runs non-destructive smoke" {
  run grep -F 'tools/smoke-nondestructive.sh' "$REPO_ROOT/tools/check.sh"

  [ "$status" -eq 0 ]
}
