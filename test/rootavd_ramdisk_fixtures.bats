#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "compression_method detects gzip magic" {
  fixture="$BATS_TEST_TMPDIR/ramdisk.img"
  printf '\x1f\x8b\x08\x00payload' > "$fixture"

  run bash -c 'SOURCING=true source "$1"; compression_method "$2"' _ "$REPO_ROOT/rootAVD.sh" "$fixture"

  [ "$status" -eq 0 ]
  [ "$output" = ".gz" ]
}

@test "compression_method detects lz4 magic" {
  fixture="$BATS_TEST_TMPDIR/ramdisk.img"
  printf '\x02\x21\x4c\x18payload' > "$fixture"

  run bash -c 'SOURCING=true source "$1"; compression_method "$2"' _ "$REPO_ROOT/rootAVD.sh" "$fixture"

  [ "$status" -eq 0 ]
  [ "$output" = ".lz4" ]
}

@test "compression_method leaves unknown magic empty" {
  fixture="$BATS_TEST_TMPDIR/ramdisk.img"
  printf 'plain payload' > "$fixture"

  run bash -c 'SOURCING=true source "$1"; compression_method "$2"' _ "$REPO_ROOT/rootAVD.sh" "$fixture"

  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "detect_ramdisk_compression_method detects gzip and renames image" {
  work="$BATS_TEST_TMPDIR/detect-gzip"
  mkdir -p "$work"
  printf '\x1f\x8b\x08\x00payload' > "$work/ramdisk.img"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    BASEDIR="$2"
    detect_ramdisk_compression_method
    printf "RDF=%s CPIO=%s CPIOORIG=%s ENDG=%s METHOD=%s GZ=%s LZ4=%s SIGN=%s\n" \
      "$RDF" "$CPIO" "$CPIOORIG" "$ENDG" "$METHOD" "$RAMDISK_GZ" "$RAMDISK_LZ4" "$COMPRESS_SIGN"
  ' _ "$REPO_ROOT/rootAVD.sh" "$work"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Ramdisk.img uses gzip compression"* ]]
  [[ "$output" == *"RDF=$work/ramdisk.img CPIO=$work/ramdisk.cpio CPIOORIG=$work/ramdisk.cpio.orig ENDG=.gz METHOD=gzip GZ=true LZ4=false SIGN=1f8b0800"* ]]
  [ ! -e "$work/ramdisk.img" ]
  [ -e "$work/ramdisk.img.gz" ]
}

@test "detect_ramdisk_compression_method detects lz4 and updates active image path" {
  work="$BATS_TEST_TMPDIR/detect-lz4"
  mkdir -p "$work"
  printf '\x02\x21\x4c\x18payload' > "$work/ramdisk.img"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    BASEDIR="$2"
    detect_ramdisk_compression_method
    printf "RDF=%s CPIO=%s CPIOORIG=%s ENDG=%s METHOD=%s GZ=%s LZ4=%s SIGN=%s\n" \
      "$RDF" "$CPIO" "$CPIOORIG" "$ENDG" "$METHOD" "$RAMDISK_GZ" "$RAMDISK_LZ4" "$COMPRESS_SIGN"
  ' _ "$REPO_ROOT/rootAVD.sh" "$work"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Ramdisk.img uses lz4_legacy compression"* ]]
  [[ "$output" == *"RDF=$work/ramdisk.img.lz4 CPIO=$work/ramdisk.cpio CPIOORIG=$work/ramdisk.cpio.orig ENDG=.lz4 METHOD=lz4_legacy GZ=false LZ4=true SIGN=02214c18"* ]]
  [ ! -e "$work/ramdisk.img" ]
  [ -e "$work/ramdisk.img.lz4" ]
}

@test "detect_ramdisk_compression_method aborts on unknown compression without renaming" {
  work="$BATS_TEST_TMPDIR/detect-unknown"
  mkdir -p "$work"
  printf 'plain payload' > "$work/ramdisk.img"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    BASEDIR="$2"
    abort_script() {
      printf "ABORT RDF=%s CPIO=%s CPIOORIG=%s ENDG=%s METHOD=%s GZ=%s LZ4=%s\n" \
        "$RDF" "$CPIO" "$CPIOORIG" "$ENDG" "$METHOD" "$RAMDISK_GZ" "$RAMDISK_LZ4"
      exit 42
    }
    detect_ramdisk_compression_method
  ' _ "$REPO_ROOT/rootAVD.sh" "$work"

  [ "$status" -eq 42 ]
  [[ "$output" == *"Ramdisk.img uses UNKNOWN compression 706c6169"* ]]
  [[ "$output" == *"ABORT RDF=$work/ramdisk.img CPIO=$work/ramdisk.cpio CPIOORIG=$work/ramdisk.cpio.orig ENDG= METHOD= GZ=false LZ4=false"* ]]
  [ -e "$work/ramdisk.img" ]
  [ ! -e "$work/ramdisk.img.gz" ]
  [ ! -e "$work/ramdisk.img.lz4" ]
}

@test "extract_stock_ramdisk clears workspace and extracts full cpio with busybox" {
  work="$BATS_TEST_TMPDIR/extract-stock"
  base="$work/base"
  tmp="$work/tmp"
  log="$work/busybox.log"
  mkdir -p "$base" "$tmp/ramdisk"
  printf '%s\n' "stale" > "$tmp/ramdisk/stale-file"
  printf '%s\n' "cpio" > "$work/ramdisk.cpio"
  cat > "$base/busybox" <<'SCRIPT'
#!/usr/bin/env bash
printf 'PWD=%s ARGS=%s\n' "$PWD" "$*" >> "$BUSYBOX_LOG"
printf '%s\n' "extracted" > extracted-from-busybox
SCRIPT
  chmod +x "$base/busybox"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    export BUSYBOX_LOG="$5"
    BASEDIR="$2"
    TMP="$3"
    CPIO="$4"
    extract_stock_ramdisk
    cat "$BUSYBOX_LOG"
    test -e "$TMP/ramdisk/extracted-from-busybox"
    test ! -e "$TMP/ramdisk/stale-file"
  ' _ "$REPO_ROOT/rootAVD.sh" "$base" "$tmp" "$work/ramdisk.cpio" "$log"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Extracting Stock ramdisk"* ]]
  [[ "$output" == *"PWD=$tmp/ramdisk ARGS=cpio -F $work/ramdisk.cpio -i"* ]]
}

@test "construct_environment aborts clearly when root access is unavailable" {
  work="$BATS_TEST_TMPDIR/construct-non-root"
  bin="$work/bin"
  mkdir -p "$bin"
  cat > "$bin/su" <<'SCRIPT'
#!/usr/bin/env bash
case "$*" in
  "-c id -u") exit 1 ;;
esac
SCRIPT
  cat > "$bin/id" <<'SCRIPT'
#!/usr/bin/env bash
case "$1" in
  -u) printf '%s\n' 2000 ;;
esac
SCRIPT
  chmod +x "$bin/su" "$bin/id"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    PATH="$2:$PATH"
    abort_script() {
      echo ABORT_SCRIPT_CALLED
      exit 42
    }
    construct_environment
  ' _ "$REPO_ROOT/rootAVD.sh" "$bin"

  [ "$status" -eq 42 ]
  [[ "$output" == *"Constructing environment - PAY ATTENTION to the AVDs Screen"* ]]
  [[ "$output" == *"not root yet"* ]]
  [[ "$output" == *"Couldn't construct environment"* ]]
  [[ "$output" == *"Double Check Root Access"* ]]
  [[ "$output" == *"ABORT_SCRIPT_CALLED"* ]]
}

@test "construct_environment issues root setup command before abort fallback" {
  work="$BATS_TEST_TMPDIR/construct-root"
  bin="$work/bin"
  log="$work/su.log"
  mkdir -p "$bin" "$work/base/assets" "$work/bindir"
  cat > "$bin/su" <<'SCRIPT'
#!/usr/bin/env bash
case "$*" in
  "-c id -u")
    printf '%s\n' 0
    ;;
  *)
    printf '%s\n' "$*" >> "$SU_LOG"
    ;;
esac
SCRIPT
  chmod +x "$bin/su"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    export SU_LOG="$6"
    PATH="$2:$PATH"
    BB="$3/busybox"
    BASEDIR="$4"
    BINDIR="$5"
    abort_script() {
      echo ABORT_SCRIPT_CALLED
      exit 42
    }
    construct_environment
  ' _ "$REPO_ROOT/rootAVD.sh" "$bin" "$work" "$work/base" "$work/bindir" "$log"

  [ "$status" -eq 42 ]
  [[ "$output" == *"we are root"* ]]
  [[ "$output" == *"not root yet"* ]]
  [[ "$output" == *"ABORT_SCRIPT_CALLED"* ]]
  [[ "$(cat "$log")" == *"rm -rf /data/adb/magisk/*"* ]]
  [[ "$(cat "$log")" == *"mkdir -p /data/adb/magisk"* ]]
  [[ "$(cat "$log")" == *"cp -af $work/bindir/. $work/base/assets/. $work/busybox /data/adb/magisk"* ]]
  [[ "$(cat "$log")" == *"chown root.root -R /data/adb/magisk"* ]]
  [[ "$(cat "$log")" == *"chmod -R 755 /data/adb/magisk"* ]]
  [[ "$(cat "$log")" == *"rm -rf $work/base"* ]]
  [[ "$(cat "$log")" == *"reboot"* ]]
}

@test "extract_patched_ramdisk clears workspace and removes existing module entries" {
  work="$BATS_TEST_TMPDIR/extract-patched"
  base="$work/base"
  tmp="$work/tmp"
  busybox_log="$work/busybox.log"
  magiskboot_log="$work/magiskboot.log"
  mkdir -p "$base" "$tmp/ramdisk"
  printf '%s\n' "stale" > "$tmp/ramdisk/stale-file"
  printf '%s\n' "cpio" > "$work/ramdisk.cpio"
  cat > "$base/busybox" <<'SCRIPT'
#!/usr/bin/env bash
printf 'PWD=%s ARGS=%s\n' "$PWD" "$*" >> "$BUSYBOX_LOG"
mkdir -p lib/modules
printf '%s\n' "module" > lib/modules/virtio.ko
SCRIPT
  cat > "$work/magiskboot" <<'SCRIPT'
#!/usr/bin/env bash
printf 'PWD=%s ARGS=%s\n' "$PWD" "$*" >> "$MAGISKBOOT_LOG"
SCRIPT
  chmod +x "$base/busybox" "$work/magiskboot"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    export BUSYBOX_LOG="$5"
    export MAGISKBOOT_LOG="$6"
    BASEDIR="$2"
    TMP="$3"
    CPIO="$4"
    extract_patched_ramdisk
    cat "$BUSYBOX_LOG"
    cat "$MAGISKBOOT_LOG"
    test -e "$TMP/ramdisk/lib/modules/virtio.ko"
    test ! -e "$TMP/ramdisk/stale-file"
  ' _ "$REPO_ROOT/rootAVD.sh" "$base" "$tmp" "$work/ramdisk.cpio" "$busybox_log" "$magiskboot_log"

  [ "$status" -eq 0 ]
  [[ "$output" == *"PWD=$tmp/ramdisk ARGS=cpio -F $work/ramdisk.cpio -i *lib*"* ]]
  [[ "$output" == *"PWD=$tmp/ramdisk ARGS=cpio ../../ramdisk.cpio rm -r /lib/modules/*"* ]]
}

@test "decompress_ramdisk hands non-gzip images directly to magiskboot" {
  work="$BATS_TEST_TMPDIR/decompress-lz4"
  base="$work/base"
  tmp="$work/tmp"
  log="$work/magiskboot.log"
  mkdir -p "$base" "$tmp"
  printf '%s\n' "single archive" > "$work/ramdisk.img.lz4"
  cat > "$base/magiskboot" <<'SCRIPT'
#!/usr/bin/env bash
printf 'ARGS=%s\n' "$*" >> "$MAGISKBOOT_LOG"
SCRIPT
  chmod +x "$base/magiskboot"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    export MAGISKBOOT_LOG="$6"
    BASEDIR="$2"
    TMP="$3"
    RDF="$4"
    CPIO="$5"
    ENDG=".lz4"
    API=29
    DERIVATE=""
    RAMDISK_GZ=false
    RAMDISK_LZ4=true
    REPACKRAMDISK=""
    decompress_ramdisk
    printf "RDF=%s REPACK=%s\n" "$RDF" "$REPACKRAMDISK"
    cat "$MAGISKBOOT_LOG"
  ' _ "$REPO_ROOT/rootAVD.sh" "$base" "$tmp" "$work/ramdisk.img.lz4" "$work/ramdisk.cpio" "$log"

  [ "$status" -eq 0 ]
  [[ "$output" == *"After decompressing ramdisk.img, magiskboot will work"* ]]
  [[ "$output" == *"RDF=$work/ramdisk.img.lz4 REPACK="* ]]
  [[ "$output" == *"ARGS=decompress $work/ramdisk.img.lz4 $work/ramdisk.cpio"* ]]
}

@test "decompress_ramdisk checks API 30 gzip images and passes compressed image to magiskboot when no repack is needed" {
  work="$BATS_TEST_TMPDIR/decompress-gzip"
  base="$work/base"
  bin="$work/bin"
  tmp="$work/tmp"
  magiskboot_log="$work/magiskboot.log"
  gzip_log="$work/gzip.log"
  mkdir -p "$base" "$bin" "$tmp"
  printf '%s\n' "single archive" > "$work/ramdisk.img"
  printf '%s\n' "compressed archive" > "$work/ramdisk.img.gz"
  cat > "$base/magiskboot" <<'SCRIPT'
#!/usr/bin/env bash
printf 'ARGS=%s\n' "$*" >> "$MAGISKBOOT_LOG"
SCRIPT
  cat > "$bin/gzip" <<'SCRIPT'
#!/usr/bin/env bash
printf 'ARGS=%s\n' "$*" >> "$GZIP_LOG"
src="${!#}"
dst="${src%.gz}"
cp "$src" "$dst"
SCRIPT
  chmod +x "$base/magiskboot" "$bin/gzip"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    export MAGISKBOOT_LOG="$7"
    export GZIP_LOG="$8"
    PATH="$9:$PATH"
    BASEDIR="$2"
    TMP="$3"
    RDF="$4"
    CPIO="$5"
    ENDG=".gz"
    API=30
    DERIVATE=""
    RAMDISK_GZ=true
    RAMDISK_LZ4=false
    REPACKRAMDISK=""
    decompress_ramdisk
    printf "RDF=%s REPACK=%s\n" "$RDF" "$REPACKRAMDISK"
    cat "$GZIP_LOG"
    cat "$MAGISKBOOT_LOG"
  ' _ "$REPO_ROOT/rootAVD.sh" "$base" "$tmp" "$work/ramdisk.img" "$work/ramdisk.cpio" "$magiskboot_log" "$gzip_log" "$bin"

  [ "$status" -eq 0 ]
  [[ "$output" == *"API level greater then 30"* ]]
  [[ "$output" == *"After decompressing ramdisk.img, magiskboot will work"* ]]
  [[ "$output" == *"RDF=$work/ramdisk.img.gz REPACK="* ]]
  [[ "$output" == *"ARGS=-fdk $work/ramdisk.img.gz"* ]]
  [[ "$output" == *"ARGS=decompress $work/ramdisk.img.gz $work/ramdisk.cpio"* ]]
}

@test "latest_magisk_patched_file picks newest patched artifact" {
  downloads="$BATS_TEST_TMPDIR/Download"
  mkdir -p "$downloads"
  old="$downloads/magisk_patched_old.img"
  new="$downloads/magisk_patched new.img"
  printf "old\n" > "$old"
  printf "new\n" > "$new"
  touch -t 202401010101 "$old"
  touch -t 202501010101 "$new"

  run bash -c 'SOURCING=true source "$1"; latest_magisk_patched_file "$2"' _ "$REPO_ROOT/rootAVD.sh" "$downloads"

  [ "$status" -eq 0 ]
  [ "$output" = "$new" ]
}

@test "remove_magisk_patched_files removes only patched artifacts" {
  downloads="$BATS_TEST_TMPDIR/Download"
  mkdir -p "$downloads"
  printf "patched\n" > "$downloads/magisk_patched one.img"
  printf "patched\n" > "$downloads/other_magisk_patched.img"
  printf "keep\n" > "$downloads/fakeboot.img"

  run bash -c 'SOURCING=true source "$1"; remove_magisk_patched_files "$2"' _ "$REPO_ROOT/rootAVD.sh" "$downloads"

  [ "$status" -eq 0 ]
  [ ! -e "$downloads/magisk_patched one.img" ]
  [ ! -e "$downloads/other_magisk_patched.img" ]
  [ -e "$downloads/fakeboot.img" ]
}

@test "rename_copy_magisk copies Magisk.zip when a version was chosen" {
  work="$BATS_TEST_TMPDIR/rename-copy"
  mkdir -p "$work"
  printf '%s\n' "magisk zip" > "$work/Magisk.zip"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    cd "$2"
    MAGISKVERCHOOSEN=true
    rename_copy_magisk
    printf "ZIP=%s APK=%s\n" "$(cat Magisk.zip)" "$(cat Magisk.apk)"
  ' _ "$REPO_ROOT/rootAVD.sh" "$work"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Copy Magisk.zip to Magisk.apk"* ]]
  [[ "$output" == *"ZIP=magisk zip APK=magisk zip"* ]]
  [ -e "$work/Magisk.zip" ]
  [ -e "$work/Magisk.apk" ]
}

@test "rename_copy_magisk moves Magisk.zip when no version was chosen" {
  work="$BATS_TEST_TMPDIR/rename-move"
  mkdir -p "$work"
  printf '%s\n' "magisk zip" > "$work/Magisk.zip"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    cd "$2"
    MAGISKVERCHOOSEN=false
    rename_copy_magisk
    printf "APK=%s\n" "$(cat Magisk.apk)"
    test ! -e Magisk.zip
  ' _ "$REPO_ROOT/rootAVD.sh" "$work"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Rename Magisk.zip to Magisk.apk"* ]]
  [[ "$output" == *"APK=magisk zip"* ]]
  [ ! -e "$work/Magisk.zip" ]
  [ -e "$work/Magisk.apk" ]
}

@test "repacking_ramdisk writes final ramdisk image without pre-compress for stock status" {
  work="$BATS_TEST_TMPDIR/repack-stock"
  log="$work/magiskboot.log"
  mkdir -p "$work"
  cat > "$work/magiskboot" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MAGISKBOOT_LOG"
SCRIPT
  chmod +x "$work/magiskboot"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    export MAGISKBOOT_LOG="$3"
    BASEDIR="$2"
    STATUS=0
    METHOD=gzip
    repacking_ramdisk
    cat "$MAGISKBOOT_LOG"
  ' _ "$REPO_ROOT/rootAVD.sh" "$work" "$log"

  [ "$status" -eq 0 ]
  [[ "$output" == *"repacking back to ramdisk.img format"* ]]
  [[ "$output" == *"compress=gzip ramdisk.cpio ramdiskpatched4AVD.img"* ]]
  [[ "$output" != *"cpio ramdisk.cpio compress"* ]]
}

@test "repacking_ramdisk pre-compresses ramdisk when status bit 4 is set" {
  work="$BATS_TEST_TMPDIR/repack-compressed"
  log="$work/magiskboot.log"
  mkdir -p "$work"
  cat > "$work/magiskboot" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MAGISKBOOT_LOG"
SCRIPT
  chmod +x "$work/magiskboot"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    export MAGISKBOOT_LOG="$3"
    BASEDIR="$2"
    STATUS=4
    METHOD=lz4_legacy
    repacking_ramdisk
    cat "$MAGISKBOOT_LOG"
  ' _ "$REPO_ROOT/rootAVD.sh" "$work" "$log"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Compressing ramdisk before repacking it"* ]]
  [[ "$output" == *"cpio ramdisk.cpio compress"* ]]
  [[ "$output" == *"compress=lz4_legacy ramdisk.cpio ramdiskpatched4AVD.img"* ]]
}

@test "patching_ramdisk builds config and patches 64-bit Magisk overlay" {
  work="$BATS_TEST_TMPDIR/patching-64"
  log="$work/magiskboot.log"
  mkdir -p "$work"
  cat > "$work/magisk64" <<'SCRIPT'
#!/usr/bin/env bash
case "$1" in
  --preinit-device) printf '%s\n' metadata ;;
esac
SCRIPT
  cat > "$work/magiskboot" <<'SCRIPT'
#!/usr/bin/env bash
printf 'ARGS=%s\n' "$*" >> "$MAGISKBOOT_LOG"
SCRIPT
  chmod +x "$work/magisk64" "$work/magiskboot"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    export MAGISKBOOT_LOG="$3"
    cd "$2"
    update_lib_modules() {
      printf "%s\n" UPDATE_LIB_MODULES_CALLED
    }

    BASEDIR="$2"
    INITLD=false
    IS32BITONLY=false
    IS64BITONLY=true
    IS64BIT=true
    STUBAPK=false
    KEEPVERITY=true
    KEEPFORCEENCRYPT=false
    RECOVERYMODE=false
    PATCHFSTAB=false
    AddRCscripts=false
    SHA1=stock-sha1
    patching_ramdisk
    cat config
    cat "$MAGISKBOOT_LOG"
  ' _ "$REPO_ROOT/rootAVD.sh" "$work" "$log"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Patching ramdisk"* ]]
  [[ "$output" == *"Pre-init storage partition: metadata"* ]]
  [[ "$output" == *"UPDATE_LIB_MODULES_CALLED"* ]]
  [[ "$output" == *"KEEPVERITY=true"* ]]
  [[ "$output" == *"KEEPFORCEENCRYPT=false"* ]]
  [[ "$output" == *"RECOVERYMODE=false"* ]]
  [[ "$output" == *"PREINITDEVICE=metadata"* ]]
  [[ "$output" == *"SHA1=stock-sha1"* ]]
  [[ "$output" == *"ARGS=compress=xz magisk64 magisk64.xz"* ]]
  [[ "$output" == *"ARGS=cpio ramdisk.cpio mkdir 0750 overlay.d mkdir 0750 overlay.d/sbin"* ]]
  [[ "$output" == *"add 0750 init magiskinit"* ]]
  [[ "$output" == *"# add 0644 overlay.d/sbin/magisk32.xz magisk32.xz"* ]]
  [[ "$output" == *"add 0644 overlay.d/sbin/magisk64.xz magisk64.xz"* ]]
  [[ "$output" == *"# add 0644 overlay.d/sbin/magisk.xz magisk.xz"* ]]
  [[ "$output" == *"# add 0644 overlay.d/sbin/stub.xz stub.xz"* ]]
  [[ "$output" == *"patch backup ramdisk.cpio.orig mkdir 000 .backup add 000 .backup/.magisk config"* ]]
}

@test "verify_ramdisk_origin reports matching kernel release" {
  work="$BATS_TEST_TMPDIR/verify-origin-match"
  bin="$work/bin"
  mkdir -p "$bin"
  printf '%s\n' "prefix" "vermagic=5.15.120-android SMP mod_unload" > "$work/ramdisk.cpio"
  cat > "$bin/uname" <<'SCRIPT'
#!/usr/bin/env bash
case "$1" in
  -r) printf '%s\n' "5.15.120-android" ;;
esac
SCRIPT
  chmod +x "$bin/uname"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    PATH="$3:$PATH"
    CPIO="$2/ramdisk.cpio"
    verify_ramdisk_origin
  ' _ "$REPO_ROOT/rootAVD.sh" "$work" "$bin"

  [ "$status" -eq 0 ]
  [[ "$output" == *"This AVD = 5.15.120-android"* ]]
  [[ "$output" == *"Ramdisk = 5.15.120-android"* ]]
  [[ "$output" == *"Ramdisk is probably from this AVD"* ]]
}

@test "verify_ramdisk_origin reports mismatching kernel release" {
  work="$BATS_TEST_TMPDIR/verify-origin-mismatch"
  bin="$work/bin"
  mkdir -p "$bin"
  printf '%s\n' "prefix" "vermagic=5.15.120-android SMP mod_unload" > "$work/ramdisk.cpio"
  cat > "$bin/uname" <<'SCRIPT'
#!/usr/bin/env bash
case "$1" in
  -r) printf '%s\n' "6.1.55-android" ;;
esac
SCRIPT
  chmod +x "$bin/uname"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    PATH="$3:$PATH"
    CPIO="$2/ramdisk.cpio"
    verify_ramdisk_origin
  ' _ "$REPO_ROOT/rootAVD.sh" "$work" "$bin"

  [ "$status" -eq 0 ]
  [[ "$output" == *"This AVD = 6.1.55-android"* ]]
  [[ "$output" == *"Ramdisk = 5.15.120-android"* ]]
  [[ "$output" == *"Ramdisk is probably NOT from this AVD"* ]]
}

@test "test_ramdisk_patch_status handles stock ramdisk and records sha1 backup" {
  work="$BATS_TEST_TMPDIR/status-stock"
  mkdir -p "$work"
  printf '%s\n' "cpio" > "$work/ramdisk.cpio"
  cat > "$work/magiskboot" <<'SCRIPT'
#!/usr/bin/env bash
case "$1" in
  cpio) exit 0 ;;
  sha1) printf '%s\n' stock-sha1 ;;
esac
SCRIPT
  chmod +x "$work/magiskboot"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    cd "$2"
    BASEDIR="$2"
    CPIO="$2/ramdisk.cpio"
    CPIOORIG="$2/ramdisk.cpio.orig"
    test_ramdisk_patch_status
    printf "STATUS=%s PATCHED=%s SHA1=%s ORIG=%s\n" "$STATUS" "$PATCHEDBOOTIMAGE" "$SHA1" "$(cat "$CPIOORIG")"
  ' _ "$REPO_ROOT/rootAVD.sh" "$work"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Stock boot image detected"* ]]
  [[ "$output" == *"STATUS=0 PATCHED=false SHA1=stock-sha1 ORIG=cpio"* ]]
}

@test "test_ramdisk_patch_status treats missing ramdisk.cpio as stock A-only image" {
  work="$BATS_TEST_TMPDIR/status-a-only"
  log="$work/magiskboot.log"
  mkdir -p "$work"
  cat > "$work/magiskboot" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MAGISKBOOT_LOG"
case "$1" in
  sha1) printf '%s\n' a-only-sha1 ;;
esac
SCRIPT
  chmod +x "$work/magiskboot"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    export MAGISKBOOT_LOG="$3"
    cd "$2"
    BASEDIR="$2"
    CPIO="$2/ramdisk.cpio"
    CPIOORIG="$2/ramdisk.cpio.orig"
    test_ramdisk_patch_status
    printf "STATUS=%s PATCHED=%s SHA1=%s\n" "$STATUS" "$PATCHEDBOOTIMAGE" "$SHA1"
    cat "$MAGISKBOOT_LOG"
  ' _ "$REPO_ROOT/rootAVD.sh" "$work" "$log"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Stock A only system-as-root"* ]]
  [[ "$output" == *"Stock boot image detected"* ]]
  [[ "$output" == *"STATUS=0 PATCHED=false SHA1=a-only-sha1"* ]]
  [[ "$output" == *"sha1 ramdisk.cpio"* ]]
  [[ "$output" != *"cpio ramdisk.cpio test"* ]]
}

@test "test_ramdisk_patch_status handles patched two-stage ramdisk" {
  work="$BATS_TEST_TMPDIR/status-patched-twostage"
  mkdir -p "$work"
  printf '%s\n' "cpio" > "$work/ramdisk.cpio"
  cat > "$work/magiskboot" <<'SCRIPT'
#!/usr/bin/env bash
case "$1" in
  cpio) exit 9 ;;
esac
SCRIPT
  chmod +x "$work/magiskboot"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    cd "$2"
    BASEDIR="$2"
    CPIO="$2/ramdisk.cpio"
    CPIOORIG="$2/ramdisk.cpio.orig"
    test_ramdisk_patch_status
    printf "STATUS=%s PATCHED=%s TWOSTAGE=%s\n" "$STATUS" "$PATCHEDBOOTIMAGE" "$TWOSTAGEINIT"
  ' _ "$REPO_ROOT/rootAVD.sh" "$work"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Magisk patched boot image detected"* ]]
  [[ "$output" == *"TWOSTAGE INIT image detected"* ]]
  [[ "$output" == *"STATUS=9 PATCHED=true TWOSTAGE=true"* ]]
}

@test "test_ramdisk_patch_status aborts unsupported patched ramdisks" {
  work="$BATS_TEST_TMPDIR/status-unsupported"
  mkdir -p "$work"
  printf '%s\n' "cpio" > "$work/ramdisk.cpio"
  cat > "$work/magiskboot" <<'SCRIPT'
#!/usr/bin/env bash
case "$1" in
  cpio) exit 2 ;;
esac
SCRIPT
  chmod +x "$work/magiskboot"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    cd "$2"
    BASEDIR="$2"
    CPIO="$2/ramdisk.cpio"
    CPIOORIG="$2/ramdisk.cpio.orig"
    abort_script() {
      echo ABORT_SCRIPT_CALLED
      exit 42
    }
    test_ramdisk_patch_status
  ' _ "$REPO_ROOT/rootAVD.sh" "$work"

  [ "$status" -eq 42 ]
  [[ "$output" == *"Boot image patched by unsupported programs"* ]]
  [[ "$output" == *"Please restore back to stock boot image"* ]]
  [[ "$output" == *"ABORT_SCRIPT_CALLED"* ]]
}

@test "apply_ramdisk_hacks adds PATCHFSTAB overlay entries" {
  work="$BATS_TEST_TMPDIR/ramdisk-work"
  bindir="$BATS_TEST_TMPDIR/bin"
  log="$BATS_TEST_TMPDIR/magiskboot.log"
  mkdir -p "$work" "$bindir"

  cat > "$bindir/magiskboot" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MAGISKBOOT_LOG"
SCRIPT
  chmod +x "$bindir/magiskboot"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    work="$2"
    bindir="$3"
    export MAGISKBOOT_LOG="$4"

    cd "$work"
    cp() {
      if [ "$1" = "/system/vendor/etc/fstab.ranchu" ]; then
        printf "base fstab\n" > fstab.ranchu
        return 0
      fi
      command cp "$@"
    }
    update_lib_modules() { :; }

    PATCHFSTAB=true
    AddRCscripts=false
    BASEDIR="$bindir"
    apply_ramdisk_hacks
  ' _ "$REPO_ROOT/rootAVD.sh" "$work" "$bindir" "$log"

  [ "$status" -eq 0 ]
  [[ "$(cat "$log")" == *"mkdir 0755 overlay.d/vendor"* ]]
  [[ "$(cat "$log")" == *"mkdir 0755 overlay.d/vendor/etc"* ]]
  [[ "$(cat "$log")" == *"add 0644 overlay.d/vendor/etc/fstab.ranchu fstab.ranchu"* ]]
  [[ "$(cat "$work/fstab.ranchu")" == *"voldmanaged=usb:auto"* ]]
}

@test "apply_ramdisk_hacks adds custom rc scripts and sbin payload" {
  work="$BATS_TEST_TMPDIR/ramdisk-rc-work"
  log="$BATS_TEST_TMPDIR/magiskboot-rc.log"
  mkdir -p "$work/sbin"
  printf '%s\n' "on boot" > "$work/custom.rc"
  printf '%s\n' "#!/system/bin/sh" > "$work/sbin/custom-service"

  cat > "$work/magiskboot" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MAGISKBOOT_LOG"
SCRIPT
  chmod +x "$work/magiskboot"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    work="$2"
    export MAGISKBOOT_LOG="$3"

    cd "$work"
    update_lib_modules() { :; }

    PATCHFSTAB=false
    AddRCscripts=true
    BASEDIR="$work"
    apply_ramdisk_hacks
  ' _ "$REPO_ROOT/rootAVD.sh" "$work" "$log"

  [ "$status" -eq 0 ]
  [[ "$(cat "$log")" == *"add 0755 overlay.d/custom.rc custom.rc"* ]]
  [[ "$(cat "$log")" == *"add 0755 overlay.d/sbin/custom-service sbin/custom-service"* ]]
}
