# shellcheck shell=bash

pushtoAVD() {
    local SRC=""
    local DST="$2"
    local ADBPUSHECHO=""
    SRC=${1##*/}

    if [[ "$DST" == "" ]]; then
        echo "[*] Push $SRC into $ADBBASEDIR"
        ADBPUSHECHO=$(adb push "$1" "$ADBBASEDIR" 2> /dev/null)
    else
        echo "[*] Push $SRC into $ADBBASEDIR/$DST"
        ADBPUSHECHO=$(adb push "$1" "$ADBBASEDIR/$DST" 2> /dev/null)
    fi

    echo "[-] $ADBPUSHECHO"
}

pullfromAVD() {
    local SRC=""
    local DST=""
    local ADBPULLECHO=""
    SRC=${1##*/}
    DST=${2##*/}
    ADBPULLECHO=$(adb pull "$ADBBASEDIR/$SRC" "$2" 2> /dev/null)
    if [[ ! "$ADBPULLECHO" == *"error"* ]]; then
        echo "[*] Pull $SRC into $DST"
        echo "[-] $ADBPULLECHO"
    fi
}

TestADB() {

    local ADB_EX=""
    local exportedADB=false

    while true; do
        echo "[-] Test if ADB SHELL is working"
        if ! command -v adb > /dev/null 2>&1; then
            if [ ! -d "$ANDROIDHOME/$ADB_DIR" ]; then
                echo "[!] ADB not found, please install and add it to your \$PATH"
                return 1
            fi

            ADB_EX=$(find "$ANDROIDHOME/$ADB_DIR" -type f -name adb -print -quit)

            if [[ "$ADB_EX" == "" ]]; then
                echo "[!] ADB binary not found in $ENVVAR/$ADB_DIR"
                return 1
            fi

            echo "[!] ADB is not in your Path, try to:"
            echo ""
            echo "export PATH=$ENVVAR/$ADB_DIR:\$PATH"
            echo ""

            if $exportedADB; then
                echo "[!] export didn't work'"
                break
            fi

            if ! checkfile "$ADB_EX"; then
                echo "[*] setting it, just during this session, for you"
                export "PATH=$ANDROIDHOME/$ADB_DIR:$PATH"
                exportedADB=true
            fi
        else
            break
        fi
    done

    ADBWORKS=$(adb shell 'echo true' 2> /dev/null)
    if [ -z "$ADBWORKS" ]; then
        echo "[!] no ADB connection possible"
        return 1
    elif [[ "$ADBWORKS" == "true" ]]; then
        echo "[*] ADB connection possible"
    fi
}

ShutDownAVD() {

    if [ "$BLUESTACKS" = true ]; then
        echo "[-] Shut-Down & Reboot BlueStacks and see if it worked"
        echo "[-] Root and Su with Magisk for BlueStacks"

        APPNAME=BlueStacks.app
        if pgrep -f "$APPNAME" > /dev/null 2>&1; then
            echo "[-] Trying to shut down BlueStacks"
            if pkill -x BlueStacks; then
                echo "[*] Shut down Signal were send"
            fi
            echo "[!] If BlueStacks doesn't shut down, try it manually!"
        fi
        echo "[*] If BlueStacks Home Screen is closing, run Magisk from the Terminal and hide it"
        echo "adb shell monkey -p com.topjohnwu.magisk -c android.intent.category.LAUNCHER 1"
    else
        echo "[-] Shut-Down & Reboot (Cold Boot Now) the AVD and see if it worked"
        echo "[-] Root and Su with Magisk for Android Studio AVDs"

        ADBPULLECHO=$(adb shell setprop sys.powerctl shutdown 2> /dev/null)
        if [[ ! "$ADBPULLECHO" == *"error"* ]]; then
            echo "[-] Trying to shut down the AVD"
        fi
        echo "[!] If the AVD doesn't shut down, try it manually!"
    fi
    echo "[-] Modded by NewBit XDA - Jan. 2021"
    echo "[!] Huge Credits and big Thanks to topjohnwu, shakalaca, vvb2060 and HuskyDG"
}
