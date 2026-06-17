#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  FAKE_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$FAKE_BIN"
  cat > "$FAKE_BIN/busybox" <<'BUSYBOX'
#!/usr/bin/env bash
cmd="$1"
shift
case "$cmd" in
  timeout)
    shift
    if [ "${BUSYBOX_ONLINE:-true}" = "true" ]; then
      exit 0
    fi
    exit 1
    ;;
  wget)
    output=""
    log_file="${BUSYBOX_WGET_LOG:-}"
    response_file=""
    output_dir=""
    url=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -O)
          output="$2"
          shift 2
          ;;
        -P)
          output_dir="$2"
          shift 2
          ;;
        -o)
          response_file="$2"
          shift 2
          ;;
        --*)
          shift
          ;;
        -*)
          shift
          ;;
        *)
          url="$1"
          shift
          ;;
      esac
    done
    if [ -n "$log_file" ]; then
      printf 'wget url=%s output=%s output_dir=%s response=%s\n' "$url" "$output" "$output_dir" "$response_file" >> "$log_file"
    fi
    if [ -n "$output" ]; then
      printf 'downloaded:%s\n' "$url" > "$output"
    fi
    if [ -n "$response_file" ]; then
      printf 'Location: https://example.test/usbhostpermissions-v1.zip\n' > "$response_file"
    fi
    exit 0
    ;;
  *)
    exec "$cmd" "$@"
    ;;
esac
BUSYBOX
  chmod +x "$FAKE_BIN/busybox"
}

@test "json_value extracts Magisk metadata fields" {
  run bash -c '
    SOURCING=true source "$1" SOURCING
    BB="$2"
    printf "%s\n" "{\"version\": \"27.0\"," "\"versionCode\": \"27000\"," "\"link\": \"Magisk.zip\"}" | json_value version 1
    printf "%s\n" "{\"version\": \"27.0\"," "\"versionCode\": \"27000\"," "\"link\": \"Magisk.zip\"}" | json_value versionCode 1
    printf "%s\n" "{\"version\": \"27.0\"," "\"versionCode\": \"27000\"," "\"link\": \"Magisk.zip\"}" | json_value link 1
  ' _ "$REPO_ROOT/rootAVD.sh" "$FAKE_BIN/busybox"

  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "27.0" ]
  [ "${lines[1]}" = "27000" ]
  [ "${lines[2]}" = "Magisk.zip" ]
}

@test "GetPrettyVer keeps dotted versions and annotates numeric versions" {
  run bash -c '
    SOURCING=true source "$1" SOURCING
    BB="$2"
    GetPrettyVer 27.0 27000
    GetPrettyVer 27000 27000
  ' _ "$REPO_ROOT/rootAVD.sh" "$FAKE_BIN/busybox"

  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "27.0" ]
  [ "${lines[1]}" = "27000(27000)" ]
}

@test "DownLoadFile downloads to explicit destination when online" {
  work="$BATS_TEST_TMPDIR/download online"
  mkdir -p "$work"

  run bash -c '
    export BUSYBOX_ONLINE=true
    SOURCING=true source "$1" SOURCING
    BB="$2"
    BASEDIR="$3"
    DownLoadFile "https://example.test/" "Magisk.zip" "custom.zip"
    cat "$BASEDIR/custom.zip"
  ' _ "$REPO_ROOT/rootAVD.sh" "$FAKE_BIN/busybox" "$work"

  [ "$status" -eq 0 ]
  [[ "$output" == *"AVD is online"* ]]
  [[ "$output" == *"Downloading File Magisk.zip complete"* ]]
  [[ "$output" == *"downloaded:https://example.test/Magisk.zip"* ]]
}

@test "DownLoadFile skips download when offline" {
  work="$BATS_TEST_TMPDIR/download offline"
  mkdir -p "$work"

  run bash -c '
    export BUSYBOX_ONLINE=false
    SOURCING=true source "$1" SOURCING
    BB="$2"
    BASEDIR="$3"
    DownLoadFile "https://example.test/" "Magisk.zip" "custom.zip"
    test ! -e "$BASEDIR/custom.zip"
  ' _ "$REPO_ROOT/rootAVD.sh" "$FAKE_BIN/busybox" "$work"

  [ "$status" -eq 0 ]
  [[ "$output" == *"AVD is offline"* ]]
}

@test "GetUSBHPmod downloads latest USB host permissions zip to sdcard download" {
  work="$BATS_TEST_TMPDIR/usbhostpermissions"
  wget_log="$work/wget.log"
  mkdir -p "$work"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    BB="$2"
    export BUSYBOX_WGET_LOG="$3"
    cd "$4"
    GetUSBHPmod
    cat "$3"
  ' _ "$REPO_ROOT/rootAVD.sh" "$FAKE_BIN/busybox" "$wget_log" "$work"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Downloading USB HOST Permissions Module Zip"* ]]
  [[ "$output" == *"url=https://gitlab.com/newbit/usbhostpermissions/-/releases/permalink/latest/downloads/usbhostpermissions"* ]]
  [[ "$output" == *"url=https://example.test/usbhostpermissions-v1.zip output= output_dir=/sdcard/Download"* ]]
}
