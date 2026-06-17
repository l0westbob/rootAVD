#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "FindUnzip fails clearly when Magisk.zip is missing" {
    run bash -c 'SOURCING=true source "$1"; MZ="$2/Magisk.zip"; FindUnzip' _ "$REPO_ROOT/rootAVD.sh" "$BATS_TEST_TMPDIR"

    [ "$status" -eq 1 ]
    [[ "$output" == *"No Magisk.zip present"* ]]
}

@test "FindUnzip uses working unzip and skips package manager fallback" {
    work="$BATS_TEST_TMPDIR/find unzip"
    fake_bin="$work/bin"
    unzip_log="$work/unzip.log"
    mkdir -p "$fake_bin"
    printf '%s\n' "fake zip" > "$work/Magisk.zip"
    cat > "$fake_bin/unzip" <<'UNZIP'
#!/usr/bin/env bash
printf '%s\n' "unzip $*" >> "$UNZIP_LOG"
exit 0
UNZIP
    chmod +x "$fake_bin/unzip"

    run bash -c '
    export PATH="$2:$PATH"
    export UNZIP_LOG="$3"
    SOURCING=true source "$1" SOURCING
    MZ="$4/Magisk.zip"
    FindWorkingBusyBox() { echo FIND_WORKING_BUSYBOX; }
    ExtractMagiskViaPM() { echo UNEXPECTED_PM_FALLBACK; return 33; }
    CopyBusyBox() { echo UNEXPECTED_COPY_BUSYBOX; return 34; }
    FindUnzip
    cat "$UNZIP_LOG"
  ' _ "$REPO_ROOT/rootAVD.sh" "$fake_bin" "$unzip_log" "$work"

    [ "$status" -eq 0 ]
    [[ "$output" == *"unzip binary found"* ]]
    [[ "$output" == *"FIND_WORKING_BUSYBOX"* ]]
    [[ "$output" == *"unzip $work/Magisk.zip -oq"* ]]
    [[ "$output" != *"UNEXPECTED_PM_FALLBACK"* ]]
    [[ "$output" != *"UNEXPECTED_COPY_BUSYBOX"* ]]
}

@test "FindUnzip falls back to package manager extraction and BusyBox unzip when unzip is unavailable" {
    work="$BATS_TEST_TMPDIR/find unzip fallback"
    busybox_log="$work/busybox.log"
    mkdir -p "$work"
    printf '%s\n' "fake zip" > "$work/Magisk.zip"
    cat > "$work/busybox" <<'BUSYBOX'
#!/usr/bin/env bash
printf '%s\n' "busybox $*" >> "$BUSYBOX_LOG"
exit 0
BUSYBOX
    chmod +x "$work/busybox"

    run bash -c '
    export BUSYBOX_LOG="$3"
    SOURCING=true source "$1" SOURCING
    MZ="$2/Magisk.zip"
    BB="$2/busybox"
    command() {
      if [ "${1:-}" = "-v" ] && [ "${2:-}" = "unzip" ]; then
        return 1
      fi
      builtin command "$@"
    }
    ExtractMagiskViaPM() { echo EXTRACT_MAGISK_VIA_PM; }
    FindWorkingBusyBox() { echo FIND_WORKING_BUSYBOX; }
    CopyBusyBox() { echo COPY_BUSYBOX; }
    FindUnzip
    cat "$BUSYBOX_LOG"
  ' _ "$REPO_ROOT/rootAVD.sh" "$work" "$busybox_log"

    [ "$status" -eq 0 ]
    [[ "$output" == *"No unzip binary found"* ]]
    [[ "$output" == *"EXTRACT_MAGISK_VIA_PM"* ]]
    [[ "$output" == *"FIND_WORKING_BUSYBOX"* ]]
    [[ "$output" == *"COPY_BUSYBOX"* ]]
    [[ "$output" == *"Extracting Magisk.zip via Busybox"* ]]
    [[ "$output" == *"busybox unzip $work/Magisk.zip -oq"* ]]
}

@test "ExecBusyBoxAsh exports Magisk prep environment and re-execs BusyBox ash" {
    work="$BATS_TEST_TMPDIR/exec busybox ash"
    mkdir -p "$work"
    cat > "$work/busybox" <<'BUSYBOX'
#!/usr/bin/env bash
printf 'ARGV=%s\n' "$*"
printf 'PREPBBMAGISK=%s\n' "$PREPBBMAGISK"
printf 'ASH_STANDALONE=%s\n' "$ASH_STANDALONE"
printf 'BASEDIR=%s\n' "$BASEDIR"
printf 'TMP=%s\n' "$TMP"
printf 'BB=%s\n' "$BB"
printf 'MZ=%s\n' "$MZ"
BUSYBOX
    chmod +x "$work/busybox"

    run bash -c '
    SOURCING=true source "$1" SOURCING
    DERIVATE=ranchu
    BASEDIR="$2"
    TMP="$2/tmp"
    BB="$2/busybox"
    MZ="$2/Magisk.zip"
    ExecBusyBoxAsh alpha beta
  ' _ "$REPO_ROOT/rootAVD.sh" "$work"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Re-Run rootAVD in Magisk Busybox STANDALONE (D)ASH"* ]]
    [[ "$output" == *"ARGV=sh _ alpha beta"* ]]
    [[ "$output" == *"PREPBBMAGISK=1"* ]]
    [[ "$output" == *"ASH_STANDALONE=1"* ]]
    [[ "$output" == *"BASEDIR=$work"* ]]
    [[ "$output" == *"TMP=$work/tmp"* ]]
    [[ "$output" == *"BB=$work/busybox"* ]]
    [[ "$output" == *"MZ=$work/Magisk.zip"* ]]
}

@test "ExecBusyBoxAsh uses BlueStacks su handoff when patching BlueStacks" {
    work="$BATS_TEST_TMPDIR/exec bluestacks ash"
    mkdir -p "$work"
    cat > "$work/su" <<'SU'
#!/usr/bin/env bash
printf 'SU_ARGV=%s\n' "$*"
printf 'PREPBBMAGISK=%s\n' "$PREPBBMAGISK"
printf 'ASH_STANDALONE=%s\n' "$ASH_STANDALONE"
printf 'BASEDIR=%s\n' "$BASEDIR"
printf 'BB=%s\n' "$BB"
printf 'MZ=%s\n' "$MZ"
SU
    chmod +x "$work/su"

    run bash -c '
    SOURCING=true source "$1" SOURCING
    DERIVATE=BlueStacks
    BASEDIR="$2"
    TMP="$2/tmp"
    BB="$2/busybox"
    MZ="$2/Magisk.zip"
    BLUESTACKS_SU="$2/su"
    CheckBlueStacksSUBinary() {
      echo CHECK_BLUESTACKS_SU
      SU="$BLUESTACKS_SU"
    }
    ExecBusyBoxAsh alpha beta
  ' _ "$REPO_ROOT/rootAVD.sh" "$work"

    [ "$status" -eq 0 ]
    [[ "$output" == *"CHECK_BLUESTACKS_SU"* ]]
    [[ "$output" == *"Re-Run rootAVD in Magisk Busybox STANDALONE (D)ASH as Root"* ]]
    [[ "$output" == *"SU_ARGV=0 $work/busybox sh _ alpha beta"* ]]
    [[ "$output" == *"PREPBBMAGISK=1"* ]]
    [[ "$output" == *"ASH_STANDALONE=1"* ]]
    [[ "$output" == *"BASEDIR=$work"* ]]
    [[ "$output" == *"BB=$work/busybox"* ]]
    [[ "$output" == *"MZ=$work/Magisk.zip"* ]]
}

@test "UpdateBusyBoxScript finishes after writing updated script" {
    work="$BATS_TEST_TMPDIR/update busybox"
    mkdir -p "$work"

    run bash -c '
    SOURCING=true source "$1" SOURCING
    ROOTAVD="$2"
    api_level_arch_detect() { :; }
    UpdateBusyBoxToScript() { echo UPDATE_BUSYBOX_SCRIPT; }
    ExecBusyBoxAsh() { echo UNEXPECTED_EXEC; return 33; }
    InstallMagiskToAVD "system-images/android-36/google_apis_playstore/x86_64/ramdisk.img" UpdateBusyBoxScript
  ' _ "$REPO_ROOT/rootAVD.sh" "$work"

    [ "$status" -eq 0 ]
    [[ "$output" == *"UPDATE_BUSYBOX_SCRIPT"* ]]
    [[ "$output" != *"UNEXPECTED_EXEC"* ]]
}

@test "PrepBusyBoxAndMagisk preserves rootAVD modules before Magisk extraction cleanup" {
    work="$BATS_TEST_TMPDIR/preserve rootavd modules"
    mkdir -p "$work/lib/rootavd" "$work/lib/arm64-v8a" "$work/assets"
    printf '%s\n' "bootstrap" > "$work/lib/rootavd/bootstrap.sh"
    printf '%s\n' "stale busybox" > "$work/lib/arm64-v8a/libbusybox.so"
    printf '%s\n' "stale asset" > "$work/assets/stale.txt"
    printf '%s\n' "zip" > "$work/Magisk.zip"

    run bash -c '
    SOURCING=true source "$1" SOURCING
    ROOTAVD="$2"
    FindUnzip() {
      printf "%s\n" "FIND_UNZIP ROOTAVD_LIB_DIR=$ROOTAVD_LIB_DIR"
      [ -f "$ROOTAVD_LIB_DIR/bootstrap.sh" ]
      mkdir -p "$BASEDIR/lib/arm64-v8a"
      printf "%s\n" "fresh busybox" > "$BASEDIR/lib/arm64-v8a/libbusybox.so"
    }
    MoveBusyBox() { echo MOVE_BUSYBOX; }
    CheckAvailableMagisks() { echo CHECK_MAGISKS; }

    PrepBusyBoxAndMagisk
    printf "BOOTSTRAP=%s\n" "$(cat "$ROOTAVD/lib/rootavd/bootstrap.sh")"
    [ ! -e "$ROOTAVD/assets/stale.txt" ]
  ' _ "$REPO_ROOT/rootAVD.sh" "$work"

    [ "$status" -eq 0 ]
    [[ "$output" == *"FIND_UNZIP ROOTAVD_LIB_DIR=$work/lib/rootavd"* ]]
    [[ "$output" == *"MOVE_BUSYBOX"* ]]
    [[ "$output" == *"CHECK_MAGISKS"* ]]
    [[ "$output" == *"BOOTSTRAP=bootstrap"* ]]
}

@test "FindWorkingBusyBox selects the first BusyBox candidate that passes extraction test" {
    work="$BATS_TEST_TMPDIR/find busybox"
    mkdir -p "$work/lib/arm" "$work/lib/arm64"
    cat > "$work/lib/arm/notbusybox" <<'SCRIPT'
#!/usr/bin/env bash
case "${1:-}" in
  head) command head "${@:2}" ;;
  *) printf '%s\n' "not a busybox" ;;
esac
SCRIPT
    cat > "$work/lib/arm/libbusybox.so" <<'SCRIPT'
#!/usr/bin/env bash
case "${1:-}" in
  head) command head "${@:2}" ;;
  *) printf '%s\n' "BusyBox v1.30 failing" ;;
esac
SCRIPT
    cat > "$work/lib/arm64/libbusybox.so" <<'SCRIPT'
#!/usr/bin/env bash
case "${1:-}" in
  head) command head "${@:2}" ;;
  *) printf '%s\n' "BusyBox v1.36 working" ;;
esac
SCRIPT
    chmod +x "$work/lib/arm/notbusybox" "$work/lib/arm/libbusybox.so" "$work/lib/arm64/libbusybox.so"

    run bash -c '
    SOURCING=true source "$1" SOURCING
    BASEDIR="$2"
    TestingBusyBoxVersion() {
      printf "TESTING=%s\n" "$1"
      [ "$1" = "$BASEDIR/lib/arm64/libbusybox.so" ]
    }
    FindWorkingBusyBox
    printf "WORKING=%s\n" "$WorkingBusyBox"
  ' _ "$REPO_ROOT/rootAVD.sh" "$work"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Finding a working Busybox Version"* ]]
    [[ "$output" == *"TESTING=$work/lib/arm/libbusybox.so"* ]]
    [[ "$output" == *"TESTING=$work/lib/arm64/libbusybox.so"* ]]
    [[ "$output" == *"Found a working Busybox Version"* ]]
    [[ "$output" == *"BusyBox v1.36 working"* ]]
    [[ "$output" == *"WORKING=$work/lib/arm64/libbusybox.so"* ]]
    [[ "$output" != *"TESTING=$work/lib/arm/notbusybox"* ]]
}

@test "FindWorkingBusyBox aborts when no candidate can extract Magisk.zip" {
    work="$BATS_TEST_TMPDIR/find busybox abort"
    mkdir -p "$work/lib/x86"
    cat > "$work/lib/x86/libbusybox.so" <<'SCRIPT'
#!/usr/bin/env bash
case "${1:-}" in
  head) command head "${@:2}" ;;
  *) printf '%s\n' "BusyBox v1.30 failing" ;;
esac
SCRIPT
    chmod +x "$work/lib/x86/libbusybox.so"

    run bash -c '
    SOURCING=true source "$1" SOURCING
    BASEDIR="$2"
    TestingBusyBoxVersion() {
      printf "TESTING=%s\n" "$1"
      return 1
    }
    abort_script() {
      echo ABORT_SCRIPT_CALLED
      exit 42
    }
    FindWorkingBusyBox
  ' _ "$REPO_ROOT/rootAVD.sh" "$work"

    [ "$status" -eq 42 ]
    [[ "$output" == *"TESTING=$work/lib/x86/libbusybox.so"* ]]
    [[ "$output" == *"Can not find any working Busybox Version"* ]]
    [[ "$output" == *"ABORT_SCRIPT_CALLED"* ]]
}

@test "CopyBusyBox copies selected BusyBox into workdir and keeps source" {
    work="$BATS_TEST_TMPDIR/copy busybox"
    mkdir -p "$work/lib/arm64"
    printf '%s\n' "busybox payload" > "$work/lib/arm64/libbusybox.so"

    run bash -c '
    SOURCING=true source "$1" SOURCING
    WorkingBusyBox="$2/lib/arm64/libbusybox.so"
    BB="$2/busybox"
    CopyBusyBox
    printf "SRC=%s DST=%s EXEC=%s\n" "$(cat "$WorkingBusyBox")" "$(cat "$BB")" "$([ -x "$BB" ] && echo yes)"
  ' _ "$REPO_ROOT/rootAVD.sh" "$work"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Copy busybox from lib to workdir"* ]]
    [[ "$output" == *"SRC=busybox payload DST=busybox payload EXEC=yes"* ]]
    [ -e "$work/lib/arm64/libbusybox.so" ]
}

@test "MoveBusyBox moves selected BusyBox into workdir" {
    work="$BATS_TEST_TMPDIR/move busybox"
    mkdir -p "$work/lib/arm64"
    printf '%s\n' "busybox payload" > "$work/lib/arm64/libbusybox.so"

    run bash -c '
    SOURCING=true source "$1" SOURCING
    WorkingBusyBox="$2/lib/arm64/libbusybox.so"
    BB="$2/busybox"
    MoveBusyBox
    printf "DST=%s EXEC=%s SRC_EXISTS=%s\n" "$(cat "$BB")" "$([ -x "$BB" ] && echo yes)" "$([ -e "$WorkingBusyBox" ] && echo yes || echo no)"
  ' _ "$REPO_ROOT/rootAVD.sh" "$work"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Move busybox from lib to workdir"* ]]
    [[ "$output" == *"DST=busybox payload EXEC=yes SRC_EXISTS=no"* ]]
    [ ! -e "$work/lib/arm64/libbusybox.so" ]
}

@test "copyARCHfiles flattens selected architecture binaries and stub apk" {
    work="$BATS_TEST_TMPDIR/arch files"
    mkdir -p "$work/lib/x86_64" "$work/lib/x86" "$work/assets"
    printf '%s\n' "magisk64" > "$work/lib/x86_64/libmagisk64.so"
    printf '%s\n' "busybox64" > "$work/lib/x86_64/libbusybox.so"
    printf '%s\n' "magisk32" > "$work/lib/x86/libmagisk32.so"
    printf '%s\n' "stub" > "$work/assets/stub.apk"
    printf '%s\n' "init loader" > "$work/init-ld"

    run bash -c '
    SOURCING=true source "$1" SOURCING
    BASEDIR="$2"
    ABI=x86_64
    ARCH32=x86
    IS64BIT=true
    IS64BITONLY=false
    copyARCHfiles
    printf "STUBAPK=%s INITLD=%s\n" "$STUBAPK" "$INITLD"
  ' _ "$REPO_ROOT/rootAVD.sh" "$work"

    [ "$status" -eq 0 ]
    [ "$(cat "$work/magisk64")" = "magisk64" ]
    [ "$(cat "$work/magisk32")" = "magisk32" ]
    [ "$(cat "$work/busybox")" = "busybox64" ]
    [ "$(cat "$work/stub.apk")" = "stub" ]
    [[ "$output" == *"STUBAPK=true INITLD=true"* ]]
}

@test "get_flags keeps verity for system-as-root and clears forceencrypt when data is available" {
    run bash -c '
    SOURCING=true source "$1" SOURCING
    grep() {
      case "$1 $2" in
        " /  /proc/mounts")
          printf "%s\n" "ext4 / ext4 rw 0 0"
          return 0
          ;;
        "-q  /system_root ")
          return 1
          ;;
        " /data  /proc/mounts")
          printf "%s\n" "tmpfs /data tmpfs rw 0 0"
          return 0
          ;;
      esac
      command grep "$@"
    }
    getprop() {
      [ "$1" = "ro.crypto.state" ] && printf "%s\n" unencrypted
    }
    DATA=true
    API=36
    get_flags >/dev/null
    printf "%s %s %s %s\n" "$KEEPVERITY" "$ISENCRYPTED" "$KEEPFORCEENCRYPT" "$RECOVERYMODE"
  ' _ "$REPO_ROOT/rootAVD.sh"

    [ "$status" -eq 0 ]
    [ "$output" = "true false false false" ]
}

@test "get_flags keeps forceencrypt for encrypted API 28 data state" {
    run bash -c '
    SOURCING=true source "$1" SOURCING
    grep() {
      case "$1 $2" in
        " /  /proc/mounts")
          printf "%s\n" "rootfs / rootfs rw 0 0"
          return 0
          ;;
        "-q  /system_root ")
          return 1
          ;;
        " /data  /proc/mounts")
          printf "%s\n" "dm-0 /data ext4 rw 0 0"
          return 0
          ;;
      esac
      command grep "$@"
    }
    getprop() {
      [ "$1" = "ro.crypto.state" ] && printf "%s\n" encrypted
    }
    DATA=false
    API=28
    get_flags >/dev/null
    printf "%s %s %s %s\n" "$KEEPVERITY" "$ISENCRYPTED" "$KEEPFORCEENCRYPT" "$RECOVERYMODE"
  ' _ "$REPO_ROOT/rootAVD.sh"

    [ "$status" -eq 0 ]
    [ "$output" = "false true true true" ]
}

@test "InstallMagiskTemporarily exchanges mismatched preinstalled Magisk without removing it again" {
    work="$BATS_TEST_TMPDIR/magisk preinstalled"
    pm_log="$work/pm.log"
    mkdir -p "$work"
    printf '%s\n' "MAGISK_VER_CODE=27000" > "$work/util_functions.sh"
    printf '%s\n' "fake zip" > "$work/Magisk.zip"

    run bash -c '
    SOURCING=true source "$1" SOURCING
    export PM_LOG="$2"
    UFSH="$3/util_functions.sh"
    MZ="$3/Magisk.zip"
    pm() {
      printf "%s\n" "pm $*" >> "$PM_LOG"
      case "$1" in
        list)
          [ "$2" = "packages" ] && [ "$3" = "magisk" ] && printf "%s\n" "package:com.topjohnwu.magisk"
          ;;
        dump)
          if [ "${2:-}" = "--help" ]; then
            return 0
          fi
          printf "%s\n" "Package [$2] versionCode=26000"
          ;;
      esac
    }

    InstallMagiskTemporarily
    RemoveTemporarilyMagisk
    printf "PKG=%s PREINSTALLED=%s\n" "$PKG_NAME" "$magiskispreinstalled"
    cat "$PM_LOG"
  ' _ "$REPO_ROOT/rootAVD.sh" "$pm_log" "$work"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Magisk Versions differ"* ]]
    [[ "$output" == *"PKG=com.topjohnwu.magisk PREINSTALLED=true"* ]]
    [ "$(grep -c '^pm clear com.topjohnwu.magisk$' "$pm_log")" -eq 1 ]
    [ "$(grep -c '^pm uninstall com.topjohnwu.magisk$' "$pm_log")" -eq 1 ]
    [ "$(grep -c '^pm install -r '"$work"'/Magisk.zip$' "$pm_log")" -eq 1 ]
}

@test "InstallMagiskTemporarily removes a Magisk app installed only for extraction" {
    work="$BATS_TEST_TMPDIR/magisk temporary"
    pm_log="$work/pm.log"
    pm_state="$work/list-count"
    mkdir -p "$work"
    printf '%s\n' "0" > "$pm_state"
    printf '%s\n' "fake zip" > "$work/Magisk.zip"

    run bash -c '
    SOURCING=true source "$1" SOURCING
    export PM_LOG="$2"
    export PM_STATE="$3"
    MZ="$4/Magisk.zip"
    pm() {
      printf "%s\n" "pm $*" >> "$PM_LOG"
      case "$1" in
        list)
          if [ "$2" = "packages" ] && [ "$3" = "magisk" ]; then
            count=$(cat "$PM_STATE")
            if [ "$count" -gt 0 ]; then
              printf "%s\n" "package:com.topjohnwu.magisk"
            fi
            printf "%s\n" "$((count + 1))" > "$PM_STATE"
          fi
          ;;
      esac
    }

    InstallMagiskTemporarily
    RemoveTemporarilyMagisk
    printf "PKG=%s PREINSTALLED=%s\n" "$PKG_NAME" "$magiskispreinstalled"
    cat "$PM_LOG"
  ' _ "$REPO_ROOT/rootAVD.sh" "$pm_log" "$pm_state" "$work"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Temporarily installing Magisk"* ]]
    [[ "$output" == *"Removing Temporarily installed Magisk"* ]]
    [[ "$output" == *"PKG=com.topjohnwu.magisk PREINSTALLED=false"* ]]
    [ "$(grep -c '^pm install -r '"$work"'/Magisk.zip$' "$pm_log")" -eq 1 ]
    [ "$(grep -c '^pm clear com.topjohnwu.magisk$' "$pm_log")" -eq 1 ]
    [ "$(grep -c '^pm uninstall com.topjohnwu.magisk$' "$pm_log")" -eq 1 ]
}

@test "api_level_arch_detect maps arm64-v8a AVD properties" {
    run bash -c '
    SOURCING=true source "$1" SOURCING
    getprop() {
      case "$1" in
        ro.product.cpu.abi) printf "%s\n" arm64-v8a ;;
        ro.product.cpu.abilist32) printf "%s\n" armeabi-v7a ;;
        ro.product.cpu.abilist64) printf "%s\n" arm64-v8a ;;
        ro.build.version.sdk) printf "%s\n" 36 ;;
        ro.product.first_api_level) printf "%s\n" 36 ;;
        ro.build.version.release) printf "%s\n" 16 ;;
      esac
    }
    api_level_arch_detect >/dev/null
    printf "%s %s %s %s %s %s %s\n" \
      "$ABI" "$ARCH" "$ARCH32" "$IS64BITONLY" "$IS32BITONLY" "$API" "$AVERSION"
  ' _ "$REPO_ROOT/rootAVD.sh"

    [ "$status" -eq 0 ]
    [ "$output" = "arm64-v8a arm64 armeabi-v7a false false 36 16" ]
}

@test "api_level_arch_detect maps x86_64 AVD properties" {
    run bash -c '
    SOURCING=true source "$1" SOURCING
    getprop() {
      case "$1" in
        ro.product.cpu.abi) printf "%s\n" x86_64 ;;
        ro.product.cpu.abilist32) printf "%s\n" x86 ;;
        ro.product.cpu.abilist64) printf "%s\n" x86_64 ;;
        ro.build.version.sdk) printf "%s\n" 36 ;;
        ro.product.first_api_level) printf "%s\n" 36 ;;
        ro.build.version.release) printf "%s\n" 16 ;;
      esac
    }
    api_level_arch_detect >/dev/null
    printf "%s %s %s %s %s %s %s\n" \
      "$ABI" "$ARCH" "$ARCH32" "$IS64BITONLY" "$IS32BITONLY" "$API" "$AVERSION"
  ' _ "$REPO_ROOT/rootAVD.sh"

    [ "$status" -eq 0 ]
    [ "$output" = "x86_64 x64 x86 false false 36 16" ]
}

@test "api_level_arch_detect maps x86 AVD properties" {
    run bash -c '
    SOURCING=true source "$1" SOURCING
    getprop() {
      case "$1" in
        ro.product.cpu.abi) printf "%s\n" x86 ;;
        ro.product.cpu.abilist32) printf "%s\n" x86 ;;
        ro.product.cpu.abilist64) printf "%s\n" "" ;;
        ro.build.version.sdk) printf "%s\n" 30 ;;
        ro.product.first_api_level) printf "%s\n" 30 ;;
        ro.build.version.release) printf "%s\n" 11 ;;
      esac
    }
    api_level_arch_detect >/dev/null
    printf "%s %s %s %s %s %s %s\n" \
      "$ABI" "$ARCH" "$ARCH32" "$IS64BITONLY" "$IS32BITONLY" "$API" "$AVERSION"
  ' _ "$REPO_ROOT/rootAVD.sh"

    [ "$status" -eq 0 ]
    [ "$output" = "x86 x86 x86 false true 30 11" ]
}

@test "api_level_arch_detect maps armeabi-v7a AVD properties" {
    run bash -c '
    SOURCING=true source "$1" SOURCING
    getprop() {
      case "$1" in
        ro.product.cpu.abi) printf "%s\n" armeabi-v7a ;;
        ro.product.cpu.abilist32) printf "%s\n" armeabi-v7a ;;
        ro.product.cpu.abilist64) printf "%s\n" "" ;;
        ro.build.version.sdk) printf "%s\n" 25 ;;
        ro.product.first_api_level) printf "%s\n" 25 ;;
        ro.build.version.release) printf "%s\n" 7.1.1 ;;
      esac
    }
    api_level_arch_detect >/dev/null
    printf "%s %s %s %s %s %s %s\n" \
      "$ABI" "$ARCH" "$ABI32" "$IS64BITONLY" "$IS32BITONLY" "$API" "$AVERSION"
  ' _ "$REPO_ROOT/rootAVD.sh"

    [ "$status" -eq 0 ]
    [ "$output" = "armeabi-v7a arm armeabi-v7a false true 25 7.1.1" ]
}
