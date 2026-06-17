# shellcheck shell=bash

get_flags() {
    echo "[-] Get Flags"
    if [ -f /system/init ] || [ -L /system/init ]; then
        SYSTEM_ROOT=true
    else
        SYSTEM_ROOT=false
        grep ' / ' /proc/mounts | grep -qv 'rootfs' || grep -q ' /system_root ' /proc/mounts && SYSTEM_ROOT=true
    fi

    if [ -z "${KEEPVERITY:-}" ]; then
        if "$SYSTEM_ROOT"; then
            KEEPVERITY=true
            echo "[*] System-as-root, keep dm/avb-verity"
        else
            KEEPVERITY=false
        fi
    fi

    ISENCRYPTED=false
    grep ' /data ' /proc/mounts | grep -q 'dm-' && ISENCRYPTED=true
    [ "$(getprop ro.crypto.state)" = "encrypted" ] && ISENCRYPTED=true

    if [ -z "${KEEPFORCEENCRYPT:-}" ]; then
        # No data access means unable to decrypt in recovery
        if "$ISENCRYPTED" || ! "$DATA"; then
            KEEPFORCEENCRYPT=true
            echo "[-] Encrypted data, keep forceencrypt"
        else
            KEEPFORCEENCRYPT=false
        fi
    fi

    RECOVERYMODE=false

    if [[ $API -eq 28 ]]; then
        RECOVERYMODE=true
    fi

    export RECOVERYMODE
    export KEEPVERITY
    export KEEPFORCEENCRYPT
    echo "[*] RECOVERYMODE=$RECOVERYMODE"
    echo "[-] KEEPVERITY=$KEEPVERITY"
    echo "[*] KEEPFORCEENCRYPT=$KEEPFORCEENCRYPT"
}

copyARCHfiles() {
    BINDIR=$BASEDIR/lib/$ABI
    ASSETSDIR=$BASEDIR/assets
    STUBAPK=false
    INITLD=false

    if [ -e "$BINDIR/libstub.so" ]; then
        ABI=$ARCH32
        BINDIR=$BASEDIR/lib/$ABI
        echo "[*] No 64-Bit Binarys found, please consider Magisk Alpha"
    elif "$IS64BIT" && ! "$IS64BITONLY"; then
        echo "[*] copy $ARCH32 files to $BINDIR"
        cp "$BASEDIR/lib/$ARCH32"/lib*32.so "$BINDIR" 2> /dev/null
    fi

    cd "$BINDIR" || return
    for file in lib*.so; do mv "$file" "${file:3:${#file}-6}"; done
    cd "$BASEDIR" || return
    echo "[-] copy all $ABI files from $BINDIR to $BASEDIR"
    cp "$BINDIR"/* "$BASEDIR" 2> /dev/null

    if [ -e "$ASSETSDIR/stub.apk" ]; then
        echo "[-] copy 'stub.apk' from $ASSETSDIR to $BASEDIR"
        cp "$ASSETSDIR/stub.apk" "$BASEDIR" 2> /dev/null
        STUBAPK=true
    fi

    if [ -e "$BASEDIR/init-ld" ]; then
        echo "[*] init LD_PRELOAD is present"
        INITLD=true
        export INITLD
    fi

    chmod -R 755 "$BASEDIR"
    export STUBAPK
}

api_level_arch_detect() {
    echo "[-] Api Level Arch Detect"
    # Detect version and architecture
    # To select the right files for the patching

    ABI=$(getprop ro.product.cpu.abi)
    ABILIST32=$(getprop ro.product.cpu.abilist32)
    ABILIST64=$(getprop ro.product.cpu.abilist64)

    API=$(getprop ro.build.version.sdk)
    FIRSTAPI=$(getprop ro.product.first_api_level)

    AVERSION=$(getprop ro.build.version.release)

    IS64BIT=false
    IS64BITONLY=false
    IS32BITONLY=false

    if [ "$ABI" = "x86" ]; then
        ARCH=x86
        ARCH32=x86
    elif [ "$ABI" = "arm64-v8a" ]; then
        ARCH=arm64
        ARCH32=armeabi-v7a
        IS64BIT=true
    elif [ "$ABI" = "x86_64" ]; then
        ARCH=x64
        ARCH32=x86
        IS64BIT=true
    else
        ARCH=arm
        ABI=armeabi-v7a
        ABI32=armeabi-v7a
        export ABI32
        IS64BIT=false
    fi

    if [ -z "$ABILIST32" ]; then
        IS64BITONLY=true
    fi

    if [ -z "$ABILIST64" ]; then
        IS32BITONLY=true
    fi

    if "$IS64BITONLY" || "$IS32BITONLY"; then
        echo "[-] Device Platform is $ARCH only"
    else
        echo "[-] Device Platform: $ARCH"
        echo "[-] ARCH32 $ARCH32"
    fi

    echo "[-] Device SDK API: $API"
    echo "[-] First API Level: $FIRSTAPI"
    echo "[-] The AVD runs on Android $AVERSION"

    [ -d /system/lib64 ] && IS64BIT=true || IS64BIT=false

    export ARCH
    export ARCH32
    export IS64BIT
    export IS64BITONLY
    export IS32BITONLY
    export ABI
    export API
    export FIRSTAPI
    export AVERSION
}

InstallMagiskTemporarily() {
    magiskispreinstalled=false

    echo "[*] Searching for pre installed Magisk Apps"
    PKG_NAMES=$(pm list packages magisk 2> /dev/null | cut -f 2 -d ":")
    PKG_NAME=""
    local MAGISK_PKG_VER_CODE=""
    local MAGISK_ZIP_VER_CODE=""

    if [[ "$PKG_NAMES" == "" ]]; then
        echo "[!] Temporarily installing Magisk"
        pm install -r "$MZ" > /dev/null 2>&1
        PKG_NAME=$(pm list packages magisk 2> /dev/null | cut -f 2 -d ":")
    else
        PKG_NAME=$PKG_NAMES

        if pm dump --help > /dev/null 2>&1; then
            MAGISK_PKG_VER_CODE=$(pm dump "$PKG_NAME" | grep versionCode= | sed 's/.*versionCode=\([0-9]\{1,\}\).*/\1/')
            #echo "MAGISK_PKG_VER_CODE=$MAGISK_PKG_VER_CODE"
            MAGISK_ZIP_VER_CODE=$(grep "$UFSH" -e "MAGISK_VER_CODE" -w | sed 's/^.*=//')
            #echo "MAGISK_ZIP_VER_CODE=$MAGISK_ZIP_VER_CODE"
            #echo "PKG_NAME=$PKG_NAME"
        fi

        if [[ "$MAGISK_PKG_VER_CODE" != "$MAGISK_ZIP_VER_CODE" ]]; then
            echo "[-] Magisk Versions differ"
            echo "[*] Exchanging pre installed Magisk App Version $MAGISK_PKG_VER_CODE"
            pm clear "$PKG_NAME" > /dev/null 2>&1
            pm uninstall "$PKG_NAME" > /dev/null 2>&1
            echo "[-] with the Magisk App Version $MAGISK_ZIP_VER_CODE"
            pm install -r "$MZ" > /dev/null 2>&1
            PKG_NAME=$(pm list packages magisk 2> /dev/null | cut -f 2 -d ":")
        fi
        if [[ "$MAGISK_PKG_VER_CODE" == "" ]]; then
            echo "[!] Found a pre installed Magisk App, use it"
        else
            echo "[!] Found a pre installed Magisk App Version $MAGISK_PKG_VER_CODE, use it"
        fi
        magiskispreinstalled=true
    fi
}

RemoveTemporarilyMagisk() {

    if ! "$magiskispreinstalled"; then
        echo "[!] Removing Temporarily installed Magisk"
        pm clear "$PKG_NAME" > /dev/null 2>&1
        pm uninstall "$PKG_NAME" > /dev/null 2>&1
    fi
}

TestingBusyBoxVersion() {

    local busyboxworks=false
    local RESULT=""
    echo "[*] Testing Busybox $1"

    rm -fR "$TMP"
    mkdir -p "$TMP"

    cd "$TMP" > /dev/null || return
    ASH_STANDALONE=1 "$1" sh -c 'grep' > /dev/null 2>&1
    RESULT="$?"
    if [[ "$RESULT" != "255" ]]; then
        "$1" unzip "$MZ" -oq > /dev/null 2>&1
        RESULT="$?"
        if [[ "$RESULT" != "0" ]]; then
            echo "[!] Busybox binary does not support extracting Magisk.zip"
        else
            busyboxworks=true
        fi
    fi
    cd - > /dev/null || return

    rm -fR "$TMP"
    "$busyboxworks" && return 0 || return 1
}

FindWorkingBusyBox() {
    echo "[*] Finding a working Busybox Version"
    local bbversion=""
    local RESULT=""

    for file in "$BASEDIR"/lib/*/*busybox*; do
        [ -e "$file" ] || continue
        chmod +x "$file"
        bbversion=$("$file" 2> /dev/null | "$file" head -n 1 2> /dev/null)
        if [[ $bbversion == *"BusyBox"* ]]; then
            TestingBusyBoxVersion "$file"
            if TestingBusyBoxVersion "$file"; then
                echo "[!] Found a working Busybox Version"
                echo "[!] $bbversion"
                export WorkingBusyBox="$file"
                return
            fi
        fi
    done
    echo "[!] Can not find any working Busybox Version"
    abort_script
}

ExtractMagiskViaPM() {
    InstallMagiskTemporarily
    PKG_PATH=$(pm path "$PKG_NAME")
    PKG_PATH=${PKG_PATH%/*}
    PKG_PATH=${PKG_PATH#*:}
    echo "[*] Copy Magisk Lib Files to workdir"
    cp -Rf "$PKG_PATH/lib" "$BASEDIR/"
    RemoveTemporarilyMagisk
}

DownloadUptoDateSript() {
    echo "[*] Trying to Download the Up-To-Date Script Version"

    local DLL_URL="https://github.com/newbit1/rootAVD/raw/master/"
    local DLL_SCRIPT="rootAVD.sh"

    ExtractMagiskViaPM
    FindWorkingBusyBox
    CopyBusyBox
    DownLoadFile "$DLL_URL" "$DLL_SCRIPT"
}

ExtractBusyboxFromScript() {
    local BBSCR=$BASEDIR/bbscript.sh
    local bblineoffset=""
    local bbline_cnt=""
    cp "$0" "$BBSCR"

    bblineoffset=$(sed -n '/BUSYBOXBINARY/=' "$BBSCR" | sort -nr)
    bbline_cnt=$(sed -n '/BUSYBOXBINARY/=' "$BBSCR" | sort -nr | sed -n '$=')

    if [[ "$bbline_cnt" -gt "3" ]]; then
        echo "[*] Extracting busybox from script ..."
        for i in $bblineoffset; do
            cp "$BBSCR" busybox
            sed -i 1,"$i"'d',"$i"'q' "$BB"
            if "$BB" > /dev/null 2>&1; then
                echo "[!] Found a working busybox Binary: $file"
                echo "[!] $("$BB" | "$BB" head -n 1)"
                break
            fi
        done
    fi

    if ! "$BB" > /dev/null 2>&1; then
        echo "[!] There is no busybox behind the script"
        #echo "[!] Run rootAVD with UpdateBusyBoxScript first"
        DownloadUptoDateSript
    fi
}

UpdateBusyBoxToScript() {
    local BBSCR=$BASEDIR/bbscript.sh
    local FSIZE=""
    cp "$0" "$BBSCR"

    # Find the first working busybox binary
    for file in libbusybox*.so; do
        [ -e "$file" ] || continue
        chmod +x "$file"
        cp -fF "$file" "$BB"
        if "$BB" > /dev/null 2>&1; then
            echo "[!] Found a working busybox Binary: $file"
            echo "[!] $("$BB" | "$BB" head -n 1)"
            break
        fi
    done

    if ! "$BB" > /dev/null 2>&1; then
        echo "[!] Can't find a working busybox Binary"
        return 0
    fi

    # Add every provided busybox binary behind the script
    for file in libbusybox*.so; do
        [ -e "$file" ] || continue
        echo "" >> "$BBSCR"
        echo "###BUSYBOXBINARY###" >> "$BBSCR"
        FSIZE=$(./busybox stat "$BBSCR" -c %s)
        "$BB" dd if="$file" oflag=seek_bytes seek="$FSIZE" of="$BBSCR" > /dev/null 2>&1
    done

    #sed -i "$((bblineoffset+1))","$last_line"'d' $BBSCR
}

CopyBusyBox() {
    echo "[*] Copy busybox from lib to workdir"
    # 	if [ -e $BASEDIR/lib ]; then
    # 		chmod -R 755 $BASEDIR/lib
    # 		cp -f $BASEDIR/lib/$ABI/libbusybox.so $BB >/dev/null 2>&1
    # 		$BB >/dev/null 2>&1 && return || cp -f $BASEDIR/lib/$ARCH32/libbusybox.so $BB >/dev/null 2>&1
    # 		$BB >/dev/null 2>&1 && return || cp -f $BASEDIR/lib/$ARCH/libbusybox.so $BB >/dev/null 2>&1
    # 	fi
    cp -fF "$WorkingBusyBox" "$BB" > /dev/null 2>&1
    chmod +x "$BB"
}

MoveBusyBox() {
    echo "[*] Move busybox from lib to workdir"
    # 	if [ -e $BASEDIR/lib ]; then
    # 		chmod -R 755 $BASEDIR/lib
    # 		mv -f $BASEDIR/lib/$ABI/libbusybox.so $BB >/dev/null 2>&1
    # 		$BB >/dev/null 2>&1 && return || mv -f $BASEDIR/lib/$ARCH32/libbusybox.so $BB >/dev/null 2>&1
    # 		$BB >/dev/null 2>&1 && return || mv -f $BASEDIR/lib/$ARCH/libbusybox.so $BB >/dev/null 2>&1
    # 	fi
    mv -f "$WorkingBusyBox" "$BB" > /dev/null 2>&1
    chmod +x "$BB"
}

FindUnzip() {
    local RESULT=""
    if [ -e "$MZ" ]; then
        echo "[*] Looking for an unzip binary"
        if command -v unzip > /dev/null 2>&1; then
            echo "[-] unzip binary found"
            echo "[*] Extracting busybox and Magisk.zip via unzip ..."
            unzip "$MZ" -oq > /dev/null 2>&1
            RESULT="$?"
            if [[ "$RESULT" != "0" ]]; then
                echo "[!] unzip binary does not support extracting Magisk.zip"
                return 1
            else
                FindWorkingBusyBox
            fi
        else
            echo "[-] No unzip binary found"
        fi

        if [[ "$RESULT" != "0" ]]; then
            ExtractMagiskViaPM
            FindWorkingBusyBox
            CopyBusyBox
            echo "[*] Extracting Magisk.zip via Busybox ..."
            "$BB" unzip "$MZ" -oq > /dev/null 2>&1
            RESULT="$?"
            if [[ "$RESULT" != "0" ]]; then
                echo "[!] Busybox binary does not support extracting Magisk.zip"
                return 1
            fi
        fi
    else
        echo "[!] No Magisk.zip present"
        return 1
    fi
}

PrepBusyBoxAndMagisk() {
    echo "[-] Switch to the location of the script file"
    BASEDIR=${ROOTAVD:-$(getdir "$0")}
    if [[ "$BASEDIR" == "." ]]; then
        BASEDIR=$(pwd)
    fi
    TMP=$BASEDIR/tmp
    BB=$BASEDIR/busybox
    MZ=$BASEDIR/Magisk.zip
    cd "$BASEDIR" || return

    if ("${UpdateBusyBoxScript:-false}"); then
        UpdateBusyBoxToScript
        return 0
    fi

    rootavd_preserve_modules_before_magisk_extract
    rm -rf lib assets
    rootavd_restore_modules_after_magisk_extract
    FindUnzip || return 1
    MoveBusyBox

    chmod -R 755 "$BASEDIR"
    CheckAvailableMagisks
}

rootavd_preserve_modules_before_magisk_extract() {
    ROOTAVD_MODULE_PRESERVE_DIR=

    if [ -d "$BASEDIR/lib/rootavd" ]; then
        mkdir -p "$TMP"
        ROOTAVD_MODULE_PRESERVE_DIR=$TMP/rootavd-preserved-modules
        rm -rf "$ROOTAVD_MODULE_PRESERVE_DIR"
        mv "$BASEDIR/lib/rootavd" "$ROOTAVD_MODULE_PRESERVE_DIR"
    fi
}

rootavd_restore_modules_after_magisk_extract() {
    if [ -n "${ROOTAVD_MODULE_PRESERVE_DIR:-}" ] && [ -d "$ROOTAVD_MODULE_PRESERVE_DIR" ]; then
        mkdir -p "$BASEDIR/lib"
        mv "$ROOTAVD_MODULE_PRESERVE_DIR" "$BASEDIR/lib/rootavd"
        ROOTAVD_LIB_DIR=$BASEDIR/lib/rootavd
        export ROOTAVD_LIB_DIR
    fi
}

ExecBusyBoxAsh() {
    export PREPBBMAGISK=1
    export ASH_STANDALONE=1
    export BASEDIR
    export TMP
    export BB
    export MZ

    if [ "$DERIVATE" == "BlueStacks" ]; then
        CheckBlueStacksSUBinary
        echo "[*] Re-Run rootAVD in Magisk Busybox STANDALONE (D)ASH as Root"
        exec "$SU" 0 "$BB" sh "$0" "$@"
    fi
    echo "[*] Re-Run rootAVD in Magisk Busybox STANDALONE (D)ASH"
    exec "$BB" sh "$0" "$@"
}
