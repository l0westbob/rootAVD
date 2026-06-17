#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "MakeBlueStacksRW backs up vbox metadata and switches Root.vdi to normal" {
  work="$BATS_TEST_TMPDIR/bluestacks"
  mkdir -p "$work"
  printf '%s\n' "root image" > "$work/Root.vdi"
  cat > "$work/Android.vbox" <<'VBOX'
<HardDisk location="Root.vdi" format="VDI" type="Readonly"/>
VBOX

  run bash -c '
    SOURCING=true source "$1" SOURCING
    BLUESTACKSPATH="$2"
    ROOTVDIFILE=Root.vdi
    AVBOX="$2/Android.vbox"
    AVBOXFILE=Android.vbox
    MakeBlueStacksRW
  ' _ "$REPO_ROOT/rootAVD.sh" "$work"

  [ "$status" -eq 0 ]
  [ -e "$work/Android.vbox.backup" ]
  grep -F 'type="Normal"' "$work/Android.vbox"
  grep -F 'type="Readonly"' "$work/Android.vbox.backup"
}

@test "CheckBlueStacksSUBinary fails clearly when built-in su is missing" {
  run bash -c '
    SOURCING=true source "$1" SOURCING
    abort_script() {
      echo ABORT_SCRIPT_CALLED
      exit 42
    }
    CheckBlueStacksSUBinary
  ' _ "$REPO_ROOT/rootAVD.sh"

  [ "$status" -eq 42 ]
  [[ "$output" == *"Checking for build-in /system/xbin/bstk/su binary"* ]]
  [[ "$output" == *"We need Root to get Root"* ]]
  [[ "$output" == *"No /system/xbin/bstk/su could be found"* ]]
  [[ "$output" == *"ABORT_SCRIPT_CALLED"* ]]
}

@test "GetBlueStacksRamdisk remounts boot path and copies ramdisk with backup" {
  work="$BATS_TEST_TMPDIR/bluestacks-get-ramdisk"
  log="$work/get-ramdisk.log"
  mkdir -p "$work/base"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    BASEDIR="$2/base"
    GET_RAMDISK_LOG="$3"

    mount() { printf "mount %s\n" "$*" >> "$GET_RAMDISK_LOG"; }
    cp() { printf "cp %s\n" "$*" >> "$GET_RAMDISK_LOG"; }

    GetBlueStacksRamdisk
    cat "$GET_RAMDISK_LOG"
  ' _ "$REPO_ROOT/rootAVD.sh" "$work" "$log"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Getting BlueStacks Ramdisk"* ]]
  [[ "$output" == *"mount -o remount,rw /boot/android"* ]]
  [[ "$output" == *"cp -fac /boot/android/android/ramdisk.img /boot/android/android/ramdisk.img.backup"* ]]
  [[ "$output" == *"cp -fac /boot/android/android/ramdisk.img $work/base/"* ]]
}

@test "FinalizeBlueStacks installs patched ramdisk and restores mount state" {
  work="$BATS_TEST_TMPDIR/bluestacks-finalize"
  log="$work/finalize.log"
  mkdir -p "$work/boot/android" "$work/base"
  printf '%s\n' "patched" > "$work/ramdiskpatched4AVD.img"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    DEBUG=false
    BA="$2/boot"
    BSTKRDF="$2/boot/android/ramdisk.img"
    BASEDIR="$2/base"
    FINALIZE_LOG="$3"
    cd "$2"

    cp() { printf "cp %s\n" "$*" >> "$FINALIZE_LOG"; }
    chmod() { printf "chmod %s\n" "$*" >> "$FINALIZE_LOG"; }
    chown() { printf "chown %s\n" "$*" >> "$FINALIZE_LOG"; }
    rm() { printf "rm %s\n" "$*" >> "$FINALIZE_LOG"; }
    mount() { printf "mount %s\n" "$*" >> "$FINALIZE_LOG"; }

    FinalizeBlueStacks
    cat "$FINALIZE_LOG"
  ' _ "$REPO_ROOT/rootAVD.sh" "$work" "$log"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Overwriting $work/boot/android/ramdisk.img with ramdiskpatched4AVD.img"* ]]
  [[ "$output" == *"cp -f ramdiskpatched4AVD.img $work/boot/android/ramdisk.img"* ]]
  [[ "$output" == *"chmod 644 $work/boot/android/ramdisk.img"* ]]
  [[ "$output" == *"chown 1000:1000 $work/boot/android/ramdisk.img"* ]]
  [[ "$output" == *"chown 2000:2000 $work/base -R"* ]]
  [[ "$output" == *"rm -rf /data/adb"* ]]
  [[ "$output" == *"mount -o remount,ro $work/boot"* ]]
}

@test "FinalizeBlueStacks debug mode skips patched ramdisk overwrite" {
  work="$BATS_TEST_TMPDIR/bluestacks-finalize-debug"
  log="$work/finalize-debug.log"
  mkdir -p "$work/boot/android" "$work/base"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    DEBUG=true
    BA="$2/boot"
    BSTKRDF="$2/boot/android/ramdisk.img"
    BASEDIR="$2/base"
    FINALIZE_LOG="$3"

    cp() { printf "cp %s\n" "$*" >> "$FINALIZE_LOG"; }
    chmod() { printf "chmod %s\n" "$*" >> "$FINALIZE_LOG"; }
    chown() { printf "chown %s\n" "$*" >> "$FINALIZE_LOG"; }
    rm() { printf "rm %s\n" "$*" >> "$FINALIZE_LOG"; }
    mount() { printf "mount %s\n" "$*" >> "$FINALIZE_LOG"; }

    FinalizeBlueStacks
    cat "$FINALIZE_LOG"
  ' _ "$REPO_ROOT/rootAVD.sh" "$work" "$log"

  [ "$status" -eq 0 ]
  [[ "$output" != *"Overwriting $work/boot/android/ramdisk.img with ramdiskpatched4AVD.img"* ]]
  [[ "$output" != *"cp -f ramdiskpatched4AVD.img $work/boot/android/ramdisk.img"* ]]
  [[ "$output" != *"chmod 644 $work/boot/android/ramdisk.img"* ]]
  [[ "$output" != *"chown 1000:1000 $work/boot/android/ramdisk.img"* ]]
  [[ "$output" == *"chown 2000:2000 $work/base -R"* ]]
  [[ "$output" == *"rm -rf /data/adb"* ]]
  [[ "$output" == *"mount -o remount,ro $work/boot"* ]]
}

@test "SettingBlueStackMagiskPermissions applies Magisk file permissions" {
  work="$BATS_TEST_TMPDIR/bluestacks-perms"
  magisk="$work/ramdisk/magisk"
  log="$BATS_TEST_TMPDIR/permissions.log"
  mkdir -p "$magisk/assets" "$work/ramdisk"
  touch "$magisk/assets/util_functions.sh"
  touch "$magisk/busybox" "$magisk/magisk64" "$magisk/magiskboot"
  touch "$magisk/magiskinit" "$magisk/overlay.sh" "$work/ramdisk/init.rc"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    BLSTKMAGISKDIR="$2"
    PERMISSION_LOG="$3"

    stat() {
      if [ "$1" = "-c" ] && [ "$2" = "%u" ] && [ "$3" = "/dev" ]; then
        printf "%s\n" 0
        return 0
      fi
      command stat "$@"
    }

    set_perm() {
      printf "%s|%s|%s|%s|%s\n" "$1" "$2" "$3" "$4" "${5:-}" >> "$PERMISSION_LOG"
    }

    SettingBlueStackMagiskPermissions
  ' _ "$REPO_ROOT/rootAVD.sh" "$magisk" "$log"

  [ "$status" -eq 0 ]
  grep -F "./busybox|0|0|0750|u:object_r:magisk_file:s0" "$log"
  grep -F "./magisk64|0|0|0750|u:object_r:magisk_exec:s0" "$log"
  grep -F "./magiskboot|0|0|0750|" "$log"
  grep -F "./magiskinit|0|0|0750|" "$log"
  grep -F "./overlay.sh|0|0|0750|" "$log"
  grep -F "../init.rc|0|0|0750|" "$log"
  grep -F "assets|0|0|0750|" "$log"
  grep -F "assets/util_functions.sh|0|0|0777|" "$log"
}

@test "InstallMagiskIntoBlueStacksRamdisk assembles Magisk payload and repacks ramdisk" {
  work="$BATS_TEST_TMPDIR/bluestacks-install"
  base="$work/base"
  tmp="$work/tmp"
  cpio="$work/ramdisk.cpio"
  mkdir -p "$base/assets" "$tmp/ramdisk"
  printf '%s\n' "asset" > "$base/assets/util_functions.sh"
  printf '%s\n' "busybox" > "$base/busybox"
  printf '%s\n' "magisk32" > "$base/magisk32"
  printf '%s\n' "magisk64" > "$base/magisk64"
  printf '%s\n' "magiskboot" > "$base/magiskboot"
  printf '%s\n' "magiskinit" > "$base/magiskinit"
  printf '%s\n' "base init" > "$tmp/ramdisk/init.rc"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    BASEDIR="$2"
    BB="$2/busybox"
    TMP="$3"
    CPIO="$4"

    magisk_loader() {
      MAGISKTMP=/dev/test-magisk
      overlay_loader=overlay-content
      magiskloader=loader-content
    }
    SettingBlueStackMagiskPermissions() {
      printf "%s\n" permissions-called > "$TMP/permissions.log"
    }
    cpio() {
      cat > /dev/null
      printf "%s\n" archive
    }

    InstallMagiskIntoBlueStacksRamdisk
  ' _ "$REPO_ROOT/rootAVD.sh" "$base" "$tmp" "$cpio"

  [ "$status" -eq 0 ]
  [ -e "$tmp/ramdisk/magisk/assets/util_functions.sh" ]
  [ -e "$tmp/ramdisk/magisk/busybox" ]
  [ -e "$tmp/ramdisk/magisk/magisk32" ]
  [ -e "$tmp/ramdisk/magisk/magisk64" ]
  [ -e "$tmp/ramdisk/magisk/magiskboot" ]
  [ -e "$tmp/ramdisk/magisk/magiskinit" ]
  [ "$(cat "$tmp/ramdisk/magisk/overlay.sh")" = "overlay-content" ]
  grep -F "base init" "$tmp/ramdisk/init.rc"
  grep -F "loader-content" "$tmp/ramdisk/init.rc"
  [ "$(cat "$tmp/permissions.log")" = "permissions-called" ]
  [ "$(cat "$cpio")" = "archive" ]
}
