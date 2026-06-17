#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "getdir handles a script path inside a directory with spaces" {
  work="$BATS_TEST_TMPDIR/path with spaces"
  mkdir -p "$work"
  cp "$REPO_ROOT/rootAVD.sh" "$work/rootAVD.sh"
  mkdir -p "$work/lib"
  cp -R "$REPO_ROOT/lib/rootavd" "$work/lib/rootavd"

  run bash -c 'SOURCING=true source "$1/rootAVD.sh"; getdir "$1/rootAVD.sh"' _ "$work"

  [ "$status" -eq 0 ]
  [ "$output" = "$work" ]
}

@test "source mode fails clearly when modules are missing" {
  work="$BATS_TEST_TMPDIR/root AVD missing modules"
  mkdir -p "$work"
  cp "$REPO_ROOT/rootAVD.sh" "$work/rootAVD.sh"

  run bash -c 'source "$1/rootAVD.sh" SOURCING' _ "$work"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing rootAVD bootstrap module"* ]]
  [[ "$output" == *"complete checkout or use the generated bundle"* ]]
}

@test "ROOTAVD_LIB_DIR can point the loader at an alternate module directory" {
  work="$BATS_TEST_TMPDIR/custom module root"
  mkdir -p "$work"
  cp -R "$REPO_ROOT/lib/rootavd" "$work/rootavd"

  run bash -c '
    ROOTAVD_LIB_DIR="$2"
    SOURCING=true source "$1" SOURCING DEBUG
    printf "%s %s\n" "$DEBUG" "$ROOTAVD_LIB_DIR"
  ' _ "$REPO_ROOT/rootAVD.sh" "$work/rootavd"

  [ "$status" -eq 0 ]
  [ "$output" = "true $work/rootavd" ]
}

@test "relocated source checkout runs through sh like the ADB payload" {
  work="$BATS_TEST_TMPDIR/adb payload checkout"
  mkdir -p "$work/lib"
  cp "$REPO_ROOT/rootAVD.sh" "$work/rootAVD.sh"
  cp -R "$REPO_ROOT/lib/rootavd" "$work/lib/rootavd"

  run sh "$work/rootAVD.sh" SOURCING DEBUG

  [ "$status" -eq 0 ]
  [[ "$output" != *"Missing rootAVD"* ]]
}
