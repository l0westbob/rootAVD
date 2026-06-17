#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  FAKE_BIN="$BATS_TEST_TMPDIR/bin"
  ADB_LOG="$BATS_TEST_TMPDIR/adb.log"
  mkdir -p "$FAKE_BIN"
  cat > "$FAKE_BIN/adb" <<'ADB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$ADB_LOG"
case "$1" in
  get-state)
    printf '%s\n' device
    ;;
  push)
    printf '%s\n' "1 file pushed"
    ;;
  shell)
    exit 0
    ;;
esac
ADB
  chmod +x "$FAKE_BIN/adb"
  export ADB_LOG
  export PATH="$FAKE_BIN:$PATH"
}

@test "ADB loader smoke pushes source and bundle payloads without patching" {
  run "$REPO_ROOT/tools/smoke-adb-load.sh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"ADB loader smoke passed"* ]]

  grep -F 'push rootAVD.sh /data/local/tmp/rootavd-smoke/rootAVD.sh' "$ADB_LOG"
  grep -F "push lib/rootavd /data/local/tmp/rootavd-smoke/lib/rootavd" "$ADB_LOG"
  grep -F 'push dist/rootAVD.sh /data/local/tmp/rootavd-smoke/rootAVD.sh' "$ADB_LOG"
  grep -F 'shell sh /data/local/tmp/rootavd-smoke/rootAVD.sh SOURCING DEBUG' "$ADB_LOG"
  run grep -F 'ramdisk.img' "$ADB_LOG"
  [ "$status" -eq 1 ]
  run grep -F 'sys.powerctl shutdown' "$ADB_LOG"
  [ "$status" -eq 1 ]
}

@test "ADB loader smoke fails clearly without adb" {
  PATH="/usr/bin:/bin"

  run "$REPO_ROOT/tools/smoke-adb-load.sh"

  [ "$status" -eq 1 ]
  [[ "$output" == *"adb not found in PATH"* ]]
}
