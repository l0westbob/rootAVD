#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "strip_next_pages extracts next page links" {
  html="$BATS_TEST_TMPDIR/page.html"
  cat > "$html" <<'HTML'
<html>
<a href="/kernel/prebuilts/page/2">Next</a>
</html>
HTML

  run bash -c 'SOURCING=true source "$1"; strip_next_pages "$2"' _ "$REPO_ROOT/rootAVD.sh" "$html"

  [ "$status" -eq 0 ]
  [[ "$output" == *'href="/kernel/prebuilts/page/2"'* ]]
}

@test "kernel build label removes html tags" {
  run bash -c 'SOURCING=true source "$1"; kernel_build_label "$2"' _ "$REPO_ROOT/rootAVD.sh" '<a href="/commit/abc">Update kernel to builds 12345</a>'

  [ "$status" -eq 0 ]
  [ "$output" = "Update kernel to builds 12345" ]
}

@test "kernel commit archive name extracts tarball id" {
  run bash -c 'SOURCING=true source "$1"; kernel_commit_archive_name "$2"' _ "$REPO_ROOT/rootAVD.sh" '<a href="/kernel/prebuilts/5.15/x86-64/+/abcdef123456">Update kernel to builds 12345</a>'

  [ "$status" -eq 0 ]
  [ "$output" = "abcdef123456.tar.gz" ]
}

@test "kernel module helpers read the first module metadata" {
  modules="$BATS_TEST_TMPDIR/modules"
  mkdir -p "$modules/lib/modules"
  printf "prefix\nvermagic=5.15.120-android SMP mod_unload\nAndroid (123456) clang\n" > "$modules/lib/modules/virtio.ko"

  run bash -c 'SOURCING=true source "$1"; module_file=$(kernel_first_module_file "$2"); printf "%s\n%s\n%s\n" "${module_file##*/}" "$(kernel_module_vermagic "$module_file")" "$(kernel_module_android_build "$module_file")"' _ "$REPO_ROOT/rootAVD.sh" "$modules"

  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "virtio.ko" ]
  [ "${lines[1]}" = "5.15.120-android" ]
  [ "${lines[2]}" = "Android (123456)" ]
}

@test "update_lib_modules replaces modules in patched ramdisk cpio" {
  work="$BATS_TEST_TMPDIR/kernel-replace"
  bindir="$work/bin"
  tmp="$work/tmp"
  log="$work/magiskboot.log"
  mkdir -p "$bindir" "$tmp"
  printf '%s\n' "initramfs" > "$work/initramfs.img"
  printf '%s\n' "ramdisk cpio" > "$work/ramdisk.cpio"

  cat > "$bindir/magiskboot" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MAGISKBOOT_LOG"
SCRIPT
  chmod +x "$bindir/magiskboot"

  cat > "$bindir/busybox" <<'SCRIPT'
#!/usr/bin/env bash
if [ "$1" = "cpio" ]; then
  case "$PWD" in
    */tmp/initramfs)
      mkdir -p lib/modules
      printf "vermagic=5.15-new SMP\nAndroid (new-build) clang\n" > lib/modules/new.ko
      printf '%s\n' "alias-entry" > modules.alias
      printf '%s\n' "/archive/path/new.ko:" > modules.dep
      printf '%s\n' "/archive/path/new.ko" > modules.load
      printf '%s\n' "softdep-entry" > modules.softdep
      ;;
    */tmp/ramdisk)
      mkdir -p lib/modules
      printf "vermagic=5.15-old SMP\nAndroid (old-build) clang\n" > lib/modules/old.ko
      ;;
  esac
fi
SCRIPT
  chmod +x "$bindir/busybox"

  run bash -c '
    SOURCING=true source "$1" SOURCING
    cd "$2"
    export MAGISKBOOT_LOG="$5"

    AVDIsOnline=false
    InstallPrebuiltKernelModules=false
    InstallKernelModules=true
    PATCHEDBOOTIMAGE=true
    TMP="$3"
    BASEDIR="$4"
    CPIO="$2/ramdisk.cpio"

    update_lib_modules
  ' _ "$REPO_ROOT/rootAVD.sh" "$work" "$tmp" "$bindir" "$log"

  [ "$status" -eq 0 ]
  grep -F "cpio $work/ramdisk.cpio rm -r lib" "$log"
  grep -F "cpio $work/ramdisk.cpio mkdir 0755 lib mkdir 0755 lib/modules" "$log"
  grep -F "add 0644 lib/modules/new.ko new.ko" "$log"
  grep -F "add 0644 lib/modules/modules.alias modules.alias" "$log"
  grep -F "add 0644 lib/modules/modules.dep modules.dep" "$log"
  grep -F "add 0644 lib/modules/modules.load modules.load" "$log"
  grep -F "add 0644 lib/modules/modules.softdep modules.softdep" "$log"
  [ -e "$tmp/ramdisk/lib/modules/new.ko" ]
  [ -e "$tmp/ramdisk/lib/modules/modules.load" ]
  [ -e "$tmp/ramdisk/lib/modules/modules.dep" ]
}
