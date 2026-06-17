# shellcheck shell=bash

install_apps() {
    local ADBECHO=""
    local PACKAGE_TO_UNINSTALL=""
    local f=""
    echo "[-] Install all APKs placed in the Apps folder"

    for f in Apps/*.apk; do
        [ -e "$f" ] || continue
        echo "[*] Trying to install $f"
        ADBECHO=$(adb install -r -d "$f" 2>&1)
        if [[ "$ADBECHO" == *"INSTALL_FAILED_UPDATE_INCOMPATIBLE"* ]]; then
            echo "$ADBECHO" | while IFS= read -r I; do echo "[*] $I"; done
            PACKAGE_TO_UNINSTALL=$(printf '%s\n' "$ADBECHO" | awk '{ for (i = 1; i < NF; i++) if ($i == "Package" && !found) { print $(i + 1); found = 1 } }')
            if [ -n "$PACKAGE_TO_UNINSTALL" ]; then
                echo "[*] Need to uninstall $PACKAGE_TO_UNINSTALL first"
                ADBECHO=$(adb uninstall "$PACKAGE_TO_UNINSTALL" 2>&1)
                echo "$ADBECHO" | while IFS= read -r I; do echo "[*] $I"; done
                ADBECHO=$(adb install -r -d "$f" 2>&1)
            fi
        fi
        echo "$ADBECHO" | while IFS= read -r I; do echo "[*] $I"; done
    done
}

AllowPermissionsTo3rdPartyAPKs() {
    echo "[!] allowing MANAGE_EXTERNAL_STORAGE permissions to..."
    local PKG_NAME=""
    pm list packages -3 2> /dev/null | cut -f 2 -d ":" | while IFS= read -r PKG_NAME; do
        [ -n "$PKG_NAME" ] || continue
        echo "[-] $PKG_NAME"
        appops set "$PKG_NAME" MANAGE_EXTERNAL_STORAGE allow
    done
}
