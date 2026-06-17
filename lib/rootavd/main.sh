# shellcheck shell=bash

CopyMagiskToAVD() {
    # Set Folders and FileNames
    echo "[*] Set Directorys"
    if ("$BLUESTACKS"); then
        # BlueStacks has its ramdisk.img within, no AVD Path needed
        # but the VBOX container Root.vdi should be backuped
        BLUESTACKSROOTVDIFILE=~/Library/BlueStacks/Android/Root.vdi
        AVBOX=~/Library/BlueStacks/Android/Android.vbox
        AVBOXFILE=${AVBOX##*/}
        export AVBOXFILE
        BLUESTACKSPATH=${BLUESTACKSROOTVDIFILE%/*}
        ROOTVDIFILE=${BLUESTACKSROOTVDIFILE##*/}
        RESTOREPATH=$BLUESTACKSPATH
    else
        AVDPATHWITHRDFFILE="$ANDROIDHOME/$1"
        AVDPATH=${AVDPATHWITHRDFFILE%/*}
        RDFFILE=${AVDPATHWITHRDFFILE##*/}
        RESTOREPATH=$AVDPATH
    fi

    if ("${restore:-false}"); then
        restore_backups "$RESTOREPATH"
        return 0
    fi

    if ("${toggleRamdisk:-false}"); then
        toggle_Ramdisk "$RESTOREPATH"
        return 0
    fi

    if ("$BLUESTACKS"); then
        if checkfile "$BLUESTACKSPATH/$ROOTVDIFILE"; then
            echo "[!] $ROOTVDIFILE not found"
            echo "[!] check your BlueStacks installation"
            return 1
        fi
        echo "[!] $ROOTVDIFILE found"
        create_backup "$BLUESTACKSROOTVDIFILE"
        MakeBlueStacksRW || return 1
    fi

    GetAVDPKGRevision
    TestADB || return 1

    # The Folder where the script was called from
    ROOTAVD=${ROOTAVD:-$(getdir "$0")}
    MAGISKZIP=$ROOTAVD/Magisk.zip

    # change to ROOTAVD directory
    cd "$ROOTAVD" || return

    # Kernel Names
    BZFILE=$ROOTAVD/bzImage
    KRFILE=kernel-ranchu

    if ("${InstallApps:-false}"); then
        install_apps
        return 0
    fi

    ADBWORKDIR=/data/data/com.android.shell
    if ! adb shell "cd $ADBWORKDIR" 2> /dev/null; then
        echo "[!] $ADBWORKDIR doesn't exist, switching to tmp'"
        ADBWORKDIR=/data/local/tmp
    fi

    ADBBASEDIR=$ADBWORKDIR/Magisk
    echo "[-] In any AVD via ADB, you can execute code without root in $ADBWORKDIR"

    echo "[*] Cleaning up the ADB working space"
    adb shell rm -rf "$ADBBASEDIR"

    echo "[*] Creating the ADB working space"
    adb shell mkdir "$ADBBASEDIR"

    # If Magisk.zip file doesn't exist, just ignore it
    if ! checkfile "$MAGISKZIP"; then
        echo "[-] Magisk installer Zip exists already"
        pushtoAVD "$MAGISKZIP"
    fi

    # Proceed with ramdisk
    if "$RAMDISKIMG"; then
        # Is it a ramdisk named img file?
        if [[ "$RDFFILE" != ramdisk*.img ]]; then
            echo "[!] please give a path to a ramdisk file"
            return 1
        fi

        create_backup "$AVDPATHWITHRDFFILE"
        pushtoAVD "$AVDPATHWITHRDFFILE" "ramdisk.img"

        if ("$InstallKernelModules"); then
            INITRAMFS=$ROOTAVD/initramfs.img
            if ! checkfile "$INITRAMFS"; then
                pushtoAVD "$INITRAMFS"
            fi
        fi

        if ("${AddRCscripts:-false}"); then
            for f in "$ROOTAVD"/*.rc; do
                [ -e "$f" ] || continue
                pushtoAVD "$f"
            done
            pushtoAVD "$ROOTAVD/sbin"
        fi
    fi

    rootavd_push_payload

    if ("${UpdateBusyBoxScript:-false}"); then
        pushtoAVD "libbusybox*.so"
    fi

    echo "[-] run the actually Boot/Ramdisk/Kernel Image Patch Script"
    echo "[*] from Magisk by topjohnwu and modded by NewBit XDA"

    if adb shell sh "$ADBBASEDIR/rootAVD.sh" "$@"; then

        if ("${UpdateBusyBoxScript:-false}"); then
            pullfromAVD "bbscript.sh" "rootAVD.sh"
            chmod +x rootAVD.sh
            return 0
        fi

        if (! "$DEBUG" && "$BLUESTACKS"); then
            pullfromAVD "Magisk.apk" "Apps/"
            pullfromAVD "Magisk.zip" "$ROOTAVD"
            echo "[-] Clean up the ADB working space"
            adb shell rm -rf "$ADBBASEDIR"
            install_apps
            ShutDownAVD
            adb kill-server
        fi

        # In Debug-Mode we can skip parts of the script
        if (! "$DEBUG" && "$RAMDISKIMG"); then

            pullfromAVD "ramdiskpatched4AVD.img" "$AVDPATHWITHRDFFILE"
            pullfromAVD "Magisk.apk" "Apps/"
            pullfromAVD "Magisk.zip" "$ROOTAVD"

            if ("${InstallPrebuiltKernelModules:-false}"); then
                pullfromAVD "$BZFILE" "$ROOTAVD"
                InstallKernelModules=true
            fi

            if ("$InstallKernelModules"); then
                if ! checkfile "$BZFILE"; then
                    create_backup "$AVDPATH/$KRFILE"
                    echo "[*] Copy $BZFILE (Kernel) into kernel-ranchu"
                    if cp "$BZFILE" "$AVDPATH/$KRFILE"; then
                        rm -f "$BZFILE" "$INITRAMFS"
                    fi
                fi
            fi

            echo "[-] Clean up the ADB working space"
            adb shell rm -rf "$ADBBASEDIR"

            install_apps
            ShutDownAVD
        fi
    fi
}

service() {
    echo "[-] service Module testing"
    #exit
}

InstallMagiskToAVD() {

    if [ -z "${PREPBBMAGISK:-}" ]; then
        ProcessArguments "$@"
        if "$SOURCING"; then
            return 0
        fi
        api_level_arch_detect
        PrepBusyBoxAndMagisk || return 1
        if "$UpdateBusyBoxScript"; then
            return 0
        fi
        ExecBusyBoxAsh "$@"
    fi

    echo "[*] rootAVD with Magisk $MAGISK_VER Installer"

    get_flags
    copyARCHfiles

    if [ "$DERIVATE" == "BlueStacks" ]; then
        GetBlueStacksRamdisk
    fi

    if "$INEMULATOR"; then
        detect_ramdisk_compression_method
        decompress_ramdisk
        AllowPermissionsTo3rdPartyAPKs
        if "$FAKEBOOTIMG"; then
            process_fake_boot_img
        fi

        test_ramdisk_patch_status
        verify_ramdisk_origin

        if [ "$DERIVATE" == "BlueStacks" ]; then
            InstallMagiskIntoBlueStacksRamdisk
        else
            if "$PATCHEDBOOTIMAGE"; then
                apply_ramdisk_hacks
            else
                patching_ramdisk
            fi
        fi

        ## Magisk Module testing
        if "$DEBUG"; then
            service
        fi

        repacking_ramdisk
        rename_copy_magisk
    fi

    if [ "$DERIVATE" == "BlueStacks" ]; then
        FinalizeBlueStacks
    fi
}

rootavd_push_payload() {
    pushtoAVD "rootAVD.sh"

    if [ "${ROOTAVD_BUNDLED:-false}" != "true" ] && [ -d "${ROOTAVD_LIB_DIR:-}" ]; then
        echo "[*] Push rootAVD modules into $ADBBASEDIR/lib"
        adb shell mkdir -p "$ADBBASEDIR/lib"
        adb push "$ROOTAVD_LIB_DIR" "$ADBBASEDIR/lib/" > /dev/null
    fi
}

rootavd_detect_runtime() {
    INEMULATOR=false
    SHELLRESULT=$(getprop 2> /dev/null)
    SHELLRESULT="$?"
    if [[ "$SHELLRESULT" == "0" ]]; then
        INEMULATOR=true
        DERIVATE=$(getprop ro.boot.hardware 2> /dev/null)
        if [[ "$DERIVATE" == "" ]]; then
            if [ -x /system/xbin/bstk/su ]; then
                DERIVATE="BlueStacks"
            fi
        fi
        if [ -n "${PREPBBMAGISK:-}" ]; then
            echo "[-] We are now in Magisk Busybox STANDALONE (D)ASH"
            # Don't use $BB from now on
        else
            echo "[!] We are in a $DERIVATE emulator shell"
        fi
    fi

    #if [[ $SHELL == "ranchu" ]]; then
    #	echo "[!] We are in an emulator shell"
    #	RANCHU=true
    #fi
    #if [[ $SHELL == "cheets" ]]; then
    #	echo "[!] We are in a ChromeOS shell"
    #	RANCHU=true
    #fi

    export DERIVATE
    export INEMULATOR
}

rootavd_print_debug_arguments() {
    if "$DEBUG"; then
        echo "[!] We are in Debug Mode"
        echo "DEBUG: $DEBUG"
        echo "PATCHFSTAB: $PATCHFSTAB"
        echo "GetUSBHPmodZ: ${GetUSBHPmodZ:-false}"
        echo "RAMDISKIMG: $RAMDISKIMG"
        echo "restore: ${restore:-false}"
        echo "InstallKernelModules: $InstallKernelModules"
        echo "InstallPrebuiltKernelModules: $InstallPrebuiltKernelModules"
        echo "ListAllAVDs: ${ListAllAVDs:-false}"
        echo "InstallApps: $InstallApps"
        echo "UpdateBusyBoxScript: $UpdateBusyBoxScript"
        echo "AddRCscripts: $AddRCscripts"
        echo "BLUESTACKS: $BLUESTACKS"
        echo "toggleRamdisk: $toggleRamdisk"
        echo "SOURCING: $SOURCING"
        echo "FAKEBOOTIMG: $FAKEBOOTIMG"
    fi
}

rootavd_run_emulator_flow() {
    InstallMagiskToAVD "$@"
}

rootavd_run_host_flow() {
    ProcessArguments "$@"
    GetANDROIDHOME

    if "$SOURCING"; then
        return 0
    fi

    rootavd_print_debug_arguments

    if (! "$InstallApps" && ! "$BLUESTACKS"); then
        # If there is no file to work with, abort the script, except if it is a BlueStacks System
        if [[ "${1:-}" == "" ]]; then
            ShowHelpText
            return 0
        fi
        if (! "$restore"); then
            if checkfile "$ANDROIDHOME/${1:-}"; then
                ShowHelpText
                return 0
            fi
        fi

    fi

    echo "[!] and we are NOT in an emulator shell"

    CopyMagiskToAVD "$@"
}

rootavd_main() {
    rootavd_detect_runtime

    if "$INEMULATOR"; then
        rootavd_run_emulator_flow "$@"
        return $?
    fi

    rootavd_run_host_flow "$@"
}
