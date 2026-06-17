#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "Windows wrapper advertises the current API example range" {
    run grep -F '25,29,30,31,32,33,34,35,36,36.1,etc.' "$REPO_ROOT/rootAVD.bat"
    [ "$status" -eq 0 ]
}

@test "Windows wrapper keeps documented command words visible" {
    run bash -c '
    wrapper="$1/rootAVD.bat"
    fixture="$1/test/fixtures/rootavd_public_arguments.expected"
    missing=0

    while IFS= read -r command_word; do
      [ -n "$command_word" ] || continue
      if ! grep -F -- "$command_word" "$wrapper" > /dev/null; then
        printf "missing Windows wrapper command word: %s\n" "$command_word"
        missing=1
      fi
    done < "$fixture"

    exit "$missing"
  ' _ "$REPO_ROOT"

    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "Windows wrapper keeps modular payload push commands" {
    run grep -F "adb push rootAVD.sh %ADBBASEDIR%" "$REPO_ROOT/rootAVD.bat"
    [ "$status" -eq 0 ]

    run grep -F 'IF EXIST "lib\rootavd"' "$REPO_ROOT/rootAVD.bat"
    [ "$status" -eq 0 ]

    run grep -F "adb shell mkdir -p %ADBBASEDIR%/lib" "$REPO_ROOT/rootAVD.bat"
    [ "$status" -eq 0 ]

    run grep -F 'adb push lib\rootavd %ADBBASEDIR%/lib/' "$REPO_ROOT/rootAVD.bat"
    [ "$status" -eq 0 ]

    run grep -F "adb shell sh %ADBBASEDIR%/rootAVD.sh %*" "$REPO_ROOT/rootAVD.bat"
    [ "$status" -eq 0 ]
}

@test "Windows wrapper keeps host-side payload support for advanced flags" {
    run grep -F "IF %AddRCscripts% (" "$REPO_ROOT/rootAVD.bat"
    [ "$status" -eq 0 ]

    run grep -F 'call :pushtoAVD "%ROOTAVD%\sbin"' "$REPO_ROOT/rootAVD.bat"
    [ "$status" -eq 0 ]

    run grep -F "IF %UpdateBusyBoxScript% (" "$REPO_ROOT/rootAVD.bat"
    [ "$status" -eq 0 ]

    run grep -F 'call :pushtoAVD "libbusybox*.so"' "$REPO_ROOT/rootAVD.bat"
    [ "$status" -eq 0 ]

    run grep -F 'call :pullfromAVD bbscript.sh "%ROOTAVD%\rootAVD.sh"' "$REPO_ROOT/rootAVD.bat"
    [ "$status" -eq 0 ]

    run grep -F ":toggle_Ramdisk" "$REPO_ROOT/rootAVD.bat"
    [ "$status" -eq 0 ]
}

@test "Windows wrapper rejects BlueStacks before ramdisk handling" {
    run grep -F "BLUESTACKS is supported by rootAVD.sh on macOS, not rootAVD.bat" "$REPO_ROOT/rootAVD.bat"
    [ "$status" -eq 0 ]

    run bash -c '
      wrapper="$1/rootAVD.bat"
      bluestacks_line=$(grep -n "IF %BLUESTACKS% (" "$wrapper" | cut -d: -f1)
      ramdisk_line=$(grep -n "Set Folders and FileNames" "$wrapper" | cut -d: -f1)

      [ -n "$bluestacks_line" ] && [ -n "$ramdisk_line" ] && [ "$bluestacks_line" -lt "$ramdisk_line" ]
    ' _ "$REPO_ROOT"
    [ "$status" -eq 0 ]
}

@test "README Windows examples include wrapper advanced modes" {
    for example in \
        'rootAVD.bat system-images\android-33\google_apis_playstore\x86_64\ramdisk.img AddRCscripts' \
        'rootAVD.bat system-images\android-33\google_apis_playstore\x86_64\ramdisk.img toggleRamdisk' \
        'rootAVD.bat system-images\android-33\google_apis_playstore\x86_64\ramdisk.img UpdateBusyBoxScript'
    do
        run grep -F "$example" "$REPO_ROOT/README.md"
        [ "$status" -eq 0 ]
    done

    run grep -F "\`BLUESTACKS\` is supported by \`rootAVD.sh\` on macOS, not by \`rootAVD.bat\`." "$REPO_ROOT/README.md"
    [ "$status" -eq 0 ]
}
