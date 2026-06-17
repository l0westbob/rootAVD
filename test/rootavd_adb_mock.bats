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
  push)
    printf '%s\n' "1 file pushed"
    ;;
  pull)
    printf '%s\n' "1 file pulled"
    ;;
  install)
    printf '%s\n' "Success"
    ;;
  shell)
    case "${2:-}" in
      "echo true")
        printf '%s\n' "true"
        ;;
      "cd /data/data/com.android.shell")
        exit 1
        ;;
    esac
    ;;
esac
ADB
  chmod +x "$FAKE_BIN/adb"
  export ADB_LOG
  export PATH="$FAKE_BIN:$PATH"
}

@test "source mode pushes rootAVD loader and modules" {
  run bash -c 'SOURCING=true source "$1"; ADBBASEDIR=/data/local/tmp/Magisk; rootavd_push_payload' _ "$REPO_ROOT/rootAVD.sh"

  [ "$status" -eq 0 ]
  grep -F 'push rootAVD.sh /data/local/tmp/Magisk' "$ADB_LOG"
  grep -F "push $REPO_ROOT/lib/rootavd /data/local/tmp/Magisk/lib/" "$ADB_LOG"
}

@test "bundled mode pushes only rootAVD script" {
  run bash -c 'SOURCING=true source "$1"; ROOTAVD_BUNDLED=true; ADBBASEDIR=/data/local/tmp/Magisk; rootavd_push_payload' _ "$REPO_ROOT/rootAVD.sh"

  [ "$status" -eq 0 ]
  grep -F 'push rootAVD.sh /data/local/tmp/Magisk' "$ADB_LOG"
  run grep -F "push $REPO_ROOT/lib/rootavd /data/local/tmp/Magisk/lib/" "$ADB_LOG"
  [ "$status" -eq 1 ]
}

@test "host flow falls back to tmp workdir and pushes modular payload" {
  sdk="$BATS_TEST_TMPDIR/sdk"
  avd_rel="system-images/android-36/google_apis_playstore/x86_64/ramdisk.img"
  avd_dir="$sdk/${avd_rel%/*}"
  mkdir -p "$avd_dir"
  printf '%s\n' "stock ramdisk" > "$sdk/$avd_rel"
  printf '%s\n' "Pkg.Revision=36.1" > "$avd_dir/source.properties"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    ProcessArguments "$2" DEBUG
    ANDROIDHOME="$3"
    CopyMagiskToAVD "$2" DEBUG
  ' _ "$REPO_ROOT/rootAVD.sh" "$avd_rel" "$sdk"

  [ "$status" -eq 0 ]
  grep -F "shell cd /data/data/com.android.shell" "$ADB_LOG"
  grep -F "shell rm -rf /data/local/tmp/Magisk" "$ADB_LOG"
  grep -F "shell mkdir /data/local/tmp/Magisk" "$ADB_LOG"
  grep -F "push $REPO_ROOT/lib/rootavd /data/local/tmp/Magisk/lib/" "$ADB_LOG"
  grep -F "shell sh /data/local/tmp/Magisk/rootAVD.sh $avd_rel DEBUG" "$ADB_LOG"
}

@test "DEBUG host flow skips pullback and post-patch cleanup" {
  sdk="$BATS_TEST_TMPDIR/sdk debug"
  avd_rel="system-images/android-36/google_apis_playstore/x86_64/ramdisk.img"
  avd_dir="$sdk/${avd_rel%/*}"
  mkdir -p "$avd_dir"
  printf '%s\n' "stock ramdisk" > "$sdk/$avd_rel"
  printf '%s\n' "Pkg.Revision=36.1" > "$avd_dir/source.properties"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    ProcessArguments "$2" DEBUG
    ANDROIDHOME="$3"
    CopyMagiskToAVD "$2" DEBUG
  ' _ "$REPO_ROOT/rootAVD.sh" "$avd_rel" "$sdk"

  [ "$status" -eq 0 ]
  grep -F "shell sh /data/local/tmp/Magisk/rootAVD.sh $avd_rel DEBUG" "$ADB_LOG"
  [ "$(grep -F -c "shell rm -rf /data/local/tmp/Magisk" "$ADB_LOG")" -eq 1 ]
  run grep -F "pull /data/local/tmp/Magisk/ramdiskpatched4AVD.img" "$ADB_LOG"
  [ "$status" -eq 1 ]
  run grep -F "pull /data/local/tmp/Magisk/Magisk.apk" "$ADB_LOG"
  [ "$status" -eq 1 ]
  run grep -F "install -r -d Apps/" "$ADB_LOG"
  [ "$status" -eq 1 ]
}

@test "normal host flow pulls patched artifacts and cleans up" {
  sdk="$BATS_TEST_TMPDIR/sdk normal"
  avd_rel="system-images/android-36/google_apis_playstore/x86_64/ramdisk.img"
  avd_dir="$sdk/${avd_rel%/*}"
  mkdir -p "$avd_dir"
  printf '%s\n' "stock ramdisk" > "$sdk/$avd_rel"
  printf '%s\n' "Pkg.Revision=36.1" > "$avd_dir/source.properties"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    ProcessArguments "$2"
    ANDROIDHOME="$3"
    CopyMagiskToAVD "$2"
  ' _ "$REPO_ROOT/rootAVD.sh" "$avd_rel" "$sdk"

  [ "$status" -eq 0 ]
  grep -F "shell sh /data/local/tmp/Magisk/rootAVD.sh $avd_rel" "$ADB_LOG"
  grep -F "pull /data/local/tmp/Magisk/ramdiskpatched4AVD.img $sdk/$avd_rel" "$ADB_LOG"
  grep -F "pull /data/local/tmp/Magisk/Magisk.apk Apps/" "$ADB_LOG"
  grep -F "pull /data/local/tmp/Magisk/Magisk.zip $REPO_ROOT" "$ADB_LOG"
  [ "$(grep -F -c "shell rm -rf /data/local/tmp/Magisk" "$ADB_LOG")" -eq 2 ]
  grep -F "shell setprop sys.powerctl shutdown" "$ADB_LOG"
}

@test "public InstallApps flow installs APKs without pushing patch payload" {
  sdk="$BATS_TEST_TMPDIR/sdk install apps"
  root="$BATS_TEST_TMPDIR/root install apps"
  mkdir -p "$sdk" "$root/Apps"
  printf '%s\n' "apk" > "$root/Apps/example.apk"

  run bash -c '
    ANDROID_HOME="$2"
    source "$1" SOURCING >/dev/null
    ROOTAVD="$3"
    SOURCING=false
    getprop() { return 1; }
    rootavd_main InstallApps
  ' _ "$REPO_ROOT/rootAVD.sh" "$sdk" "$root"

  [ "$status" -eq 0 ]
  grep -F "install -r -d Apps/example.apk" "$ADB_LOG"
  run grep -F "push rootAVD.sh" "$ADB_LOG"
  [ "$status" -eq 1 ]
  run grep -F "shell mkdir /data/local/tmp/Magisk" "$ADB_LOG"
  [ "$status" -eq 1 ]
}

@test "UpdateBusyBoxScript host flow preserves busybox payload and pullback" {
  sdk="$BATS_TEST_TMPDIR/sdk"
  avd_rel="system-images/android-36/google_apis_playstore/x86_64/ramdisk.img"
  avd_dir="$sdk/${avd_rel%/*}"
  mkdir -p "$avd_dir"
  printf '%s\n' "stock ramdisk" > "$sdk/$avd_rel"
  printf '%s\n' "Pkg.Revision=36.1" > "$avd_dir/source.properties"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    ProcessArguments "$2" UpdateBusyBoxScript
    ANDROIDHOME="$3"
    CopyMagiskToAVD "$2" UpdateBusyBoxScript
  ' _ "$REPO_ROOT/rootAVD.sh" "$avd_rel" "$sdk"

  [ "$status" -eq 0 ]
  grep -F 'push libbusybox*.so /data/local/tmp/Magisk' "$ADB_LOG"
  grep -F "shell sh /data/local/tmp/Magisk/rootAVD.sh $avd_rel UpdateBusyBoxScript" "$ADB_LOG"
  grep -F "pull /data/local/tmp/Magisk/bbscript.sh rootAVD.sh" "$ADB_LOG"
}

@test "AddRCscripts host flow pushes rc scripts and sbin payload" {
  sdk="$BATS_TEST_TMPDIR/sdk"
  root="$BATS_TEST_TMPDIR/root payload"
  avd_rel="system-images/android-36/google_apis_playstore/x86_64/ramdisk.img"
  avd_dir="$sdk/${avd_rel%/*}"
  mkdir -p "$avd_dir" "$root/sbin"
  printf '%s\n' "stock ramdisk" > "$sdk/$avd_rel"
  printf '%s\n' "Pkg.Revision=36.1" > "$avd_dir/source.properties"
  printf '%s\n' "on boot" > "$root/custom.rc"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    ProcessArguments "$2" AddRCscripts DEBUG
    ROOTAVD="$4"
    ROOTAVD_LIB_DIR="$5"
    ANDROIDHOME="$3"
    CopyMagiskToAVD "$2" AddRCscripts DEBUG
  ' _ "$REPO_ROOT/rootAVD.sh" "$avd_rel" "$sdk" "$root" "$REPO_ROOT/lib/rootavd"

  [ "$status" -eq 0 ]
  grep -F "push $root/custom.rc /data/local/tmp/Magisk" "$ADB_LOG"
  grep -F "push $root/sbin /data/local/tmp/Magisk" "$ADB_LOG"
  grep -F "shell sh /data/local/tmp/Magisk/rootAVD.sh $avd_rel AddRCscripts DEBUG" "$ADB_LOG"
}

@test "InstallKernelModules host flow pushes local initramfs image" {
  sdk="$BATS_TEST_TMPDIR/sdk"
  root="$BATS_TEST_TMPDIR/kernel payload"
  avd_rel="system-images/android-36/google_apis_playstore/x86_64/ramdisk.img"
  avd_dir="$sdk/${avd_rel%/*}"
  mkdir -p "$avd_dir" "$root"
  printf '%s\n' "stock ramdisk" > "$sdk/$avd_rel"
  printf '%s\n' "Pkg.Revision=36.1" > "$avd_dir/source.properties"
  printf '%s\n' "initramfs" > "$root/initramfs.img"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    ProcessArguments "$2" InstallKernelModules DEBUG
    ROOTAVD="$4"
    ROOTAVD_LIB_DIR="$5"
    ANDROIDHOME="$3"
    CopyMagiskToAVD "$2" InstallKernelModules DEBUG
  ' _ "$REPO_ROOT/rootAVD.sh" "$avd_rel" "$sdk" "$root" "$REPO_ROOT/lib/rootavd"

  [ "$status" -eq 0 ]
  grep -F "push $root/initramfs.img /data/local/tmp/Magisk" "$ADB_LOG"
  grep -F "shell sh /data/local/tmp/Magisk/rootAVD.sh $avd_rel InstallKernelModules DEBUG" "$ADB_LOG"
}

@test "InstallKernelModules normal host flow replaces kernel-ranchu from local bzImage" {
  sdk="$BATS_TEST_TMPDIR/sdk kernel replace"
  root="$BATS_TEST_TMPDIR/kernel replace payload"
  avd_rel="system-images/android-36/google_apis_playstore/x86_64/ramdisk.img"
  avd_dir="$sdk/${avd_rel%/*}"
  mkdir -p "$avd_dir" "$root"
  printf '%s\n' "stock ramdisk" > "$sdk/$avd_rel"
  printf '%s\n' "old kernel" > "$avd_dir/kernel-ranchu"
  printf '%s\n' "Pkg.Revision=36.1" > "$avd_dir/source.properties"
  printf '%s\n' "initramfs" > "$root/initramfs.img"
  printf '%s\n' "new kernel" > "$root/bzImage"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    ProcessArguments "$2" InstallKernelModules
    ROOTAVD="$4"
    ROOTAVD_LIB_DIR="$5"
    ANDROIDHOME="$3"
    CopyMagiskToAVD "$2" InstallKernelModules
  ' _ "$REPO_ROOT/rootAVD.sh" "$avd_rel" "$sdk" "$root" "$REPO_ROOT/lib/rootavd"

  [ "$status" -eq 0 ]
  grep -F "shell sh /data/local/tmp/Magisk/rootAVD.sh $avd_rel InstallKernelModules" "$ADB_LOG"
  [ "$(cat "$avd_dir/kernel-ranchu")" = "new kernel" ]
  [ "$(cat "$avd_dir/kernel-ranchu.backup")" = "old kernel" ]
  [ ! -e "$root/bzImage" ]
  [ ! -e "$root/initramfs.img" ]
}

@test "InstallPrebuiltKernelModules host flow pulls downloaded kernel" {
  sdk="$BATS_TEST_TMPDIR/sdk prebuilt"
  root="$BATS_TEST_TMPDIR/prebuilt payload"
  avd_rel="system-images/android-36/google_apis_playstore/x86_64/ramdisk.img"
  avd_dir="$sdk/${avd_rel%/*}"
  mkdir -p "$avd_dir" "$root"
  printf '%s\n' "stock ramdisk" > "$sdk/$avd_rel"
  printf '%s\n' "Pkg.Revision=36.1" > "$avd_dir/source.properties"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    ProcessArguments "$2" InstallPrebuiltKernelModules
    ROOTAVD="$4"
    ROOTAVD_LIB_DIR="$5"
    ANDROIDHOME="$3"
    CopyMagiskToAVD "$2" InstallPrebuiltKernelModules
  ' _ "$REPO_ROOT/rootAVD.sh" "$avd_rel" "$sdk" "$root" "$REPO_ROOT/lib/rootavd"

  [ "$status" -eq 0 ]
  grep -F "shell sh /data/local/tmp/Magisk/rootAVD.sh $avd_rel InstallPrebuiltKernelModules" "$ADB_LOG"
  grep -F "pull /data/local/tmp/Magisk/bzImage $root" "$ADB_LOG"
  run grep -F "push $root/initramfs.img" "$ADB_LOG"
  [ "$status" -eq 1 ]
}

@test "BLUESTACKS host flow uses BlueStacks setup without ramdisk payload" {
  sdk="$BATS_TEST_TMPDIR/sdk bluestacks"
  root="$BATS_TEST_TMPDIR/bluestacks payload"
  mkdir -p "$sdk" "$root"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    ProcessArguments BLUESTACKS DEBUG
    ROOTAVD="$3"
    ROOTAVD_LIB_DIR="$4"
    ANDROIDHOME="$2"
    checkfile() { return 1; }
    create_backup() { printf "BACKUP:%s\n" "$1"; }
    MakeBlueStacksRW() { echo MAKE_BLUESTACKS_RW; }
    CopyMagiskToAVD BLUESTACKS DEBUG
  ' _ "$REPO_ROOT/rootAVD.sh" "$sdk" "$root" "$REPO_ROOT/lib/rootavd"

  [ "$status" -eq 0 ]
  [[ "$output" == *"MAKE_BLUESTACKS_RW"* ]]
  grep -F "shell sh /data/local/tmp/Magisk/rootAVD.sh BLUESTACKS DEBUG" "$ADB_LOG"
  grep -F "push rootAVD.sh /data/local/tmp/Magisk" "$ADB_LOG"
  run grep -F "push $sdk/" "$ADB_LOG"
  [ "$status" -eq 1 ]
  run grep -F "ramdisk.img" "$ADB_LOG"
  [ "$status" -eq 1 ]
}
