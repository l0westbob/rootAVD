#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    FAKE_BIN="$BATS_TEST_TMPDIR/bin"
    ADB_LOG="$BATS_TEST_TMPDIR/adb.log"
    ADB_STATE="$BATS_TEST_TMPDIR/adb-state"
    mkdir -p "$FAKE_BIN"
    : > "$ADB_LOG"
    cat > "$FAKE_BIN/adb" << 'ADB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$ADB_LOG"
case "$1" in
  install)
    apk="${*: -1}"
    case "${apk##*/}" in
      conflict.apk)
        if [ ! -e "$ADB_STATE/conflict-uninstalled" ]; then
          printf '%s\n' "Failure [INSTALL_FAILED_UPDATE_INCOMPATIBLE: Package com.example.conflict signatures do not match]"
        else
          printf '%s\n' "Success"
        fi
        ;;
      *)
        case "${apk##*/}" in
          broken.apk) printf '%s\n' "Failure [INSTALL_FAILED_INVALID_APK]" ;;
          *) printf '%s\n' "Success" ;;
        esac
        ;;
    esac
    ;;
  uninstall)
    mkdir -p "$ADB_STATE"
    printf '%s\n' "Success"
    if [ "${2:-}" = "com.example.conflict" ]; then
      : > "$ADB_STATE/conflict-uninstalled"
    fi
    ;;
esac
ADB
    chmod +x "$FAKE_BIN/adb"
    cat > "$FAKE_BIN/pm" << 'PM'
#!/usr/bin/env bash
case "$*" in
  "list packages -3")
    printf '%s\n' "package:com.example.one" "package:com.example.two"
    ;;
esac
PM
    cat > "$FAKE_BIN/appops" << 'APPOPS'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$APPOPS_LOG"
APPOPS
    chmod +x "$FAKE_BIN/pm" "$FAKE_BIN/appops"
    export ADB_LOG
    export ADB_STATE
    export APPOPS_LOG="$BATS_TEST_TMPDIR/appops.log"
    export PATH="$FAKE_BIN:$PATH"
}

@test "install_apps installs APKs from Apps directory" {
    work="$BATS_TEST_TMPDIR/app install"
    mkdir -p "$work/Apps"
    printf '%s\n' "apk" > "$work/Apps/normal.apk"

    run bash -c 'cd "$2"; SOURCING=true source "$1"; install_apps' _ "$REPO_ROOT/rootAVD.sh" "$work"

    [ "$status" -eq 0 ]
    grep -F "install -r -d Apps/normal.apk" "$ADB_LOG"
    [[ "$output" == *"Success"* ]]
}

@test "install_apps ignores non-APK placeholders" {
    work="$BATS_TEST_TMPDIR/app placeholder"
    mkdir -p "$work/Apps"
    printf '%s\n' "placeholder" > "$work/Apps/.gitkeep"

    run bash -c 'cd "$2"; SOURCING=true source "$1"; install_apps' _ "$REPO_ROOT/rootAVD.sh" "$work"

    [ "$status" -eq 0 ]
    run grep -F "install -r -d" "$ADB_LOG"
    [ "$status" -eq 1 ]
}

@test "install_apps uninstalls incompatible package and retries" {
    work="$BATS_TEST_TMPDIR/app reinstall"
    mkdir -p "$work/Apps"
    printf '%s\n' "apk" > "$work/Apps/conflict.apk"

    run bash -c 'cd "$2"; SOURCING=true source "$1"; install_apps' _ "$REPO_ROOT/rootAVD.sh" "$work"

    [ "$status" -eq 0 ]
    [ "$(grep -F -c "install -r -d Apps/conflict.apk" "$ADB_LOG")" -eq 2 ]
    grep -F "uninstall com.example.conflict" "$ADB_LOG"
    [[ "$output" == *"Need to uninstall com.example.conflict first"* ]]
    [[ "$output" == *"Success"* ]]
}

@test "install_apps reports non-retryable install failures once" {
    work="$BATS_TEST_TMPDIR/app broken"
    mkdir -p "$work/Apps"
    printf '%s\n' "apk" > "$work/Apps/broken.apk"

    run bash -c 'cd "$2"; SOURCING=true source "$1"; install_apps' _ "$REPO_ROOT/rootAVD.sh" "$work"

    [ "$status" -eq 0 ]
    [ "$(grep -F -c "install -r -d Apps/broken.apk" "$ADB_LOG")" -eq 1 ]
    [[ "$output" == *"INSTALL_FAILED_INVALID_APK"* ]]
}

@test "AllowPermissionsTo3rdPartyAPKs grants storage appops to third-party packages" {
    run bash -c 'SOURCING=true source "$1"; AllowPermissionsTo3rdPartyAPKs' _ "$REPO_ROOT/rootAVD.sh"

    [ "$status" -eq 0 ]
    grep -F "set com.example.one MANAGE_EXTERNAL_STORAGE allow" "$APPOPS_LOG"
    grep -F "set com.example.two MANAGE_EXTERNAL_STORAGE allow" "$APPOPS_LOG"
}
