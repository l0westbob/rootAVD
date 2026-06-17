#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "rootavd_main routes to host flow when getprop is unavailable" {
    run bash -c '
    source "$1" SOURCING >/dev/null
    getprop() { return 1; }
    rootavd_run_host_flow() { printf "HOST:%s\n" "$INEMULATOR"; }
    rootavd_run_emulator_flow() { echo UNEXPECTED_EMULATOR; return 33; }
    rootavd_main ListAllAVDs
  ' _ "$REPO_ROOT/rootAVD.sh"

    [ "$status" -eq 0 ]
    [ "$output" = "HOST:false" ]
}

@test "rootavd_main routes to emulator flow when getprop works" {
    run bash -c '
    source "$1" SOURCING >/dev/null
    getprop() {
      case "${1:-}" in
        "") return 0 ;;
        ro.boot.hardware) printf "%s\n" ranchu ;;
      esac
    }
    rootavd_run_host_flow() { echo UNEXPECTED_HOST; return 33; }
    rootavd_run_emulator_flow() { printf "EMULATOR:%s:%s\n" "$INEMULATOR" "$DERIVATE"; }
    rootavd_main "system-images/android-36/google_apis_playstore/x86_64/ramdisk.img"
  ' _ "$REPO_ROOT/rootAVD.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"We are in a ranchu emulator shell"* ]]
    [[ "$output" == *"EMULATOR:true:ranchu"* ]]
}

@test "SOURCING prevents emulator Magisk preparation" {
    run bash -c '
    source "$1" SOURCING >/dev/null
    getprop() {
      case "${1:-}" in
        "") return 0 ;;
        ro.boot.hardware) printf "%s\n" ranchu ;;
      esac
    }
    api_level_arch_detect() { echo UNEXPECTED_API_DETECT; return 33; }
    PrepBusyBoxAndMagisk() { echo UNEXPECTED_PREP; return 33; }
    rootavd_main SOURCING DEBUG
    printf "SOURCING:%s DEBUG:%s\n" "$SOURCING" "$DEBUG"
  ' _ "$REPO_ROOT/rootAVD.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"We are in a ranchu emulator shell"* ]]
    [[ "$output" == *"SOURCING:true DEBUG:true"* ]]
    [[ "$output" != *"UNEXPECTED_API_DETECT"* ]]
    [[ "$output" != *"UNEXPECTED_PREP"* ]]
}

@test "FAKEBOOTIMG emulator flow processes fake boot image before patch selection" {
    run bash -c '
    source "$1" SOURCING >/dev/null
    ProcessArguments "system-images/android-36/google_apis_playstore/x86_64/ramdisk.img" FAKEBOOTIMG
    PREPBBMAGISK=true
    MAGISK_VER=test
    DERIVATE=ranchu
    INEMULATOR=true
    order=""

    record() {
      order="${order}${1}
"
    }

    get_flags() { record get_flags; }
    copyARCHfiles() { record copyARCHfiles; }
    detect_ramdisk_compression_method() { record detect_ramdisk_compression_method; }
    decompress_ramdisk() { record decompress_ramdisk; }
    AllowPermissionsTo3rdPartyAPKs() { record AllowPermissionsTo3rdPartyAPKs; }
    process_fake_boot_img() { record process_fake_boot_img; }
    test_ramdisk_patch_status() {
      record test_ramdisk_patch_status
      PATCHEDBOOTIMAGE=true
    }
    verify_ramdisk_origin() { record verify_ramdisk_origin; }
    apply_ramdisk_hacks() { record apply_ramdisk_hacks; }
    patching_ramdisk() {
      echo UNEXPECTED_PATCHING_RAMDISK
      return 33
    }
    repacking_ramdisk() { record repacking_ramdisk; }
    rename_copy_magisk() { record rename_copy_magisk; }

    InstallMagiskToAVD "system-images/android-36/google_apis_playstore/x86_64/ramdisk.img" FAKEBOOTIMG
    printf "%s" "$order"
  ' _ "$REPO_ROOT/rootAVD.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"process_fake_boot_img
test_ramdisk_patch_status
verify_ramdisk_origin
apply_ramdisk_hacks"* ]]
    [[ "$output" == *"repacking_ramdisk
rename_copy_magisk"* ]]
    [[ "$output" != *"UNEXPECTED_PATCHING_RAMDISK"* ]]
}
