#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "TestADB discovers adb from ANDROIDHOME platform-tools when PATH lacks adb" {
  sdk="$BATS_TEST_TMPDIR/sdk"
  adb_log="$BATS_TEST_TMPDIR/adb.log"
  mkdir -p "$sdk/platform-tools"
  cat > "$sdk/platform-tools/adb" <<'ADB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$ADB_LOG"
if [ "$1" = "shell" ] && [ "${2:-}" = "echo true" ]; then
  printf '%s\n' "true"
fi
ADB
  chmod +x "$sdk/platform-tools/adb"

  run bash -c '
    export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
    export ADB_LOG="$3"
    ANDROID_HOME="$2" SOURCING=true source "$1" SOURCING >/dev/null
    ANDROIDHOME="$2"
    ENVVAR="\$ANDROID_HOME"
    ADB_DIR=platform-tools
    TestADB
    command -v adb
  ' _ "$REPO_ROOT/rootAVD.sh" "$sdk" "$adb_log"

  [ "$status" -eq 0 ]
  [[ "$output" == *"ADB is not in your Path"* ]]
  [[ "$output" == *"ADB connection possible"* ]]
  [[ "$output" == *"$sdk/platform-tools/adb"* ]]
  grep -F "shell echo true" "$adb_log"
}

@test "TestADB fails clearly when platform-tools is missing" {
  sdk="$BATS_TEST_TMPDIR/sdk without platform tools"
  mkdir -p "$sdk"

  run bash -c '
    export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
    ANDROID_HOME="$2" SOURCING=true source "$1" SOURCING >/dev/null
    ANDROIDHOME="$2"
    ENVVAR="\$ANDROID_HOME"
    ADB_DIR=platform-tools
    TestADB
  ' _ "$REPO_ROOT/rootAVD.sh" "$sdk"

  [ "$status" -eq 1 ]
  [[ "$output" == *"ADB not found, please install and add it to your \$PATH"* ]]
}

@test "TestADB fails clearly when platform-tools has no adb binary" {
  sdk="$BATS_TEST_TMPDIR/sdk without adb"
  mkdir -p "$sdk/platform-tools"

  run bash -c '
    export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
    ANDROID_HOME="$2" SOURCING=true source "$1" SOURCING >/dev/null
    ANDROIDHOME="$2"
    ENVVAR="\$ANDROID_HOME"
    ADB_DIR=platform-tools
    TestADB
  ' _ "$REPO_ROOT/rootAVD.sh" "$sdk"

  [ "$status" -eq 1 ]
  [[ "$output" == *"ADB binary not found in \$ANDROID_HOME/platform-tools"* ]]
}
